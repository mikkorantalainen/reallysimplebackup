# config for backup:

# directory to save all backups to
BACKUP_DIR="/backups/auto"

# name of the latest backup
ACTIVE_BACKUP="latest"

# name of the copy of latest backup after backup-rotate
# NOTE! should not be changed without also modifying /usr/bin/reallysimplebackup-list-old-print0
BACKUP_NAME=$(date +%Y%m%dT%H%M%S)


# name of the lock file
BACKUP_LOCK="auto.lock"

# include / exclude config files
INCLUDE_FILE="/etc/reallysimplebackup/include"
EXCLUDE_FILE="/etc/reallysimplebackup/exclude"

