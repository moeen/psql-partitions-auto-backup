#!/bin/bash

IFS=$'\n'

CONNECTION_STRING="<BACKUP_SERVER>"
BACKUP_SERVER="<BACKUP_SERVER_ADDRESS>"
BACKUP_DIR="<BACKUP_DIR>"
DATABASE_NAME="<DATABASE_NAME>"
TABLE_NAME="<TABLE_NAME>"
TABLES_TO_KEEP=2

if ! tables=$(psql ${CONNECTION_STRING} --csv -c "SELECT tablename FROM pg_catalog.pg_tables WHERE tablename LIKE '${TABLE_NAME}_p%' ORDER BY tablename;"); then
  echo "$(date)" : failed to catch tables from server
  exit 1
fi

# remove first element which is "tablename"
tables=$(echo "$tables" | tail -n +2)

# replace ${TABLE_NAME}_ in table names
tables="${tables//${TABLE_NAME}_/}"

if [[ -z "$tables" ]]; then
  echo "$(date)" : no tables has been found
  exit 0
fi

# current week number
week_number=$(date +%V)

# we want to delete table from ${TABLES_TO_KEEP} weeks ago
n_to_be_deleted=$((10#$week_number - $TABLES_TO_KEEP))
table_to_be_deleted="p$(date +%G)w$(printf "%02d" ${n_to_be_deleted})"

found=false

for table in ${tables}; do
  if [[ "$table" == "$table_to_be_deleted" ]]; then
    found=true

    table_full_name="${TABLE_NAME}_${table}"
    echo "$(date)" : deleting "$table_full_name"

    # detach partition from ${TABLE_NAME} table
    if ! psql ${CONNECTION_STRING} -c "ALTER TABLE ${DATABASE_NAME}.${TABLE_NAME} DETACH PARTITION ${DATABASE_NAME}.$table_full_name"; then
      echo "$(date)" : could not detach table "$table_full_name"
      exit 1
    fi
    echo "$(date)" : "$table_full_name" is detached

    # dump and gzip the table
    if ! pg_dump ${CONNECTION_STRING} --table "${DATABASE_NAME}.${table_full_name}" | gzip > "/tmp/${table_full_name}.sql.gz"; then
      echo "$(date)" : failed to dump "$table_full_name"
      exit 1
    fi
    echo "$(date)" : "$table_full_name" is dumped in local

    # upload dumped file to ${BACKUP_SERVER}
    if ! rsync -avH /tmp/"$table_full_name".sql.gz -e ssh root@${BACKUP_SERVER}:${BACKUP_DIR}; then
      echo "$(date)" : failed to upload "$table_full_name".sql.gz to ${BACKUP_SERVER}
      exit 1
    fi
    echo "$(date)" : "$table_full_name" is uploaded

    rm /tmp/"$table_full_name".sql.gz

    # drop the table
    if ! psql ${CONNECTION_STRING} -c "DROP TABLE ${DATABASE_NAME}.${table_full_name}"; then
      echo "$(date)" : could not drop table "$table_full_name"
      exit 1
    fi
    echo "$(date)" : "$table_full_name" is droped

    echo "$(date)" : "$table_full_name" is now deleted
  fi
done

if [[ "$found" == false ]]; then
  echo "$(date)" : tables did not need to be deleted
  exit 0
fi
