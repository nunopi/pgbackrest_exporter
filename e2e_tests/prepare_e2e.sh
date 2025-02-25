#!/usr/bin/env bash

# Exit on errors and on command pipe failures.
set -e

EXPORTER_CONFIG="${1}"

PG_CLUSTER="main"
PG_DATABASE="test_db"
PG_BIN="/usr/lib/postgresql/13/bin"
PG_DATA="/var/lib/postgresql/13/${PG_CLUSTER}"
BACKREST_STANZA="demo"
EXPORTER_BIN="/etc/pgbackrest/pgbackrest_exporter"

# Enable checksums.
${PG_BIN}/pg_checksums -e -D ${PG_DATA}
# Start postgres.
pg_ctlcluster 13 ${PG_CLUSTER} start
# Create  database.
psql -c "create database ${PG_DATABASE}"
db_oid=$(psql -t -c "select OID from pg_database where datname='demo_db';")
# Create stanza.
pgbackrest stanza-create --stanza ${BACKREST_STANZA} --log-level-console warn
# Create full backup for stanza  in repo1.
pgbackrest backup --stanza ${BACKREST_STANZA} --type full --log-level-console warn
# Create full bakup for stanza in repo2.
pgbackrest backup --stanza ${BACKREST_STANZA} --type full --repo 2 --log-level-console warn 
# Currupt database file.
db_file=$(find ${PG_DATA}/base/${db_oid} -type f -regextype egrep -regex '.*/([0-9]){4}$' -print | head -n 1)
echo "currupt" >> ${db_file} 
# Create diff backup with corrupted databse file in repo1.
pgbackrest backup --stanza ${BACKREST_STANZA} --type diff  --repo 2 --log-level-console warn
# Run pgbackrest_exporter.
if [[ ! -z ${EXPORTER_CONFIG} ]]; then
    $(${EXPORTER_BIN} --backrest.database-count --backrest.database-count-latest --prom.web-config=${EXPORTER_CONFIG})
else
    $(${EXPORTER_BIN} --backrest.database-count --backrest.database-count-latest)
fi
