#!/bin/sh

set -e

CHINOOK_POSTGRES_URL="https://raw.githubusercontent.com/lerocha/chinook-database/master/ChinookDatabase/DataSources/Chinook_PostgreSql.sql"
EXPECTED_SHA256="6945d59e3bca94591e2a96451b9bd69084b026f7fb7dbda3d15d06114ffb34c4"

PGCONNSTR=$1
PGDB=$2
PGDB_TMP="${PGDB}_tmp"

PGCONNSTR_TEMPLATE1="$PGCONNSTR dbname=template1"
PGCONNSTR_DB="$PGCONNSTR dbname=$PGDB"
PGCONNSTR_TMP="$PGCONNSTR dbname=$PGDB_TMP"

db_exists() {
    psql -lAt "$1" | awk -F "|" '{print $1}' | grep -Fx "$2" > /dev/null
}

run_psql () {
    psql "$1" -c "$2" -q
}

run_template1() {
    run_psql "$PGCONNSTR_TEMPLATE1" "$1"
}

print_open_statement() {
    echo "chinook <- connectPostgreSQL \"$PGCONNSTR_DB\""
}

if db_exists "$PGCONNSTR_TEMPLATE1" "$PGDB"; then
    print_open_statement
    exit 0
fi

if [ ! -f chinook-data/Chinook_PostgreSql.sql ]; then
    status "Downloading Postgres chinook data..."
    download "chinook-data/Chinook_PostgreSql.sql.tmp" "$CHINOOK_POSTGRES_URL" "$EXPECTED_SHA256"

    status "Converting file"
    cat "chinook-data/Chinook_PostgreSql.sql.tmp" | iconv -f ISO-8859-2 -t UTF-8 > chinook-data/Chinook_PostgreSql.sql.conv

    status "Finished conversion"
    mv chinook-data/Chinook_PostgreSql.sql.conv chinook-data/Chinook_PostgreSql.sql
    rm chinook-data/Chinook_PostgreSql.sql.tmp
fi

status "Creating Postgres database $PGDB ..."

status "First creating temporary db $PGDB_TMP"

run_template1 "DROP DATABASE IF EXISTS \"$PGDB_TMP\""
run_template1 "CREATE DATABASE \"$PGDB_TMP\""

pv chinook-data/Chinook_PostgreSql.sql | psql "$PGCONNSTR_TMP" --single-transaction -q

status "Success, renaming $PGDB_TMP to $PGDB"
run_template1 "ALTER DATABASE \"$PGDB_TMP\" RENAME TO \"$PGDB\""

print_open_statement