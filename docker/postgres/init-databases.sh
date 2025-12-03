#!/bin/bash
# Initialize multiple PostgreSQL databases
# This script is called during postgres container initialization

set -e

function create_database() {
    local database_name=$1
    echo "Creating database '$database_name'..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database_name;
        GRANT ALL PRIVILEGES ON DATABASE $database_name TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database setup detected"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_database $db
    done
    echo "Multiple databases created"
fi
