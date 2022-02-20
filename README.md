# PostgresQL partiotioned tables automated backup and drop

This script will help you to create automated backup (**compressed**) and automated deletion for your PostgresQL partitioned tables.

> NOTE: This only works if you configured pg_partman to create partiotions weekly.

## Steps

### Install these packages
1. `postgres-clinet`
2. `openssh-client`
2. `rsync`

### Configure the script
Open `psql-partitions-auto-backup.bash` and set these variables:
- `CONNECTION_STRING`: Your PostgresQL connection string
- `BACKUP_SERVER`: Server that you want to store your backups on. Should have SSH.
- `BACKUP_DIR`: Directory in `<BACKUP_SERVER>` which backups will be saved to.
- `DATABASE_NAME`: Your PostgresQL database name.
- `TABLE_NAME`: Name of the table that has partitioning.
- `TABLES_TO_KEEP`: Number of tables to keep.

### Run the script

```sh
chmod +x psql-partitions-auto-backup.bash
./psql-partitions-auto-backup.bash
```

Also you can add it as a cron job.