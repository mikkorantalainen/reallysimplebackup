#!/bin/bash
# run rsync the whole system niced and ioniced to idle IO levels

# config:
source "/etc/reallysimplebackup/config"

# the script:

if [ "$1" = "after-reboot" ]; then
	rm  --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK" 2>/dev/null
	echo "Sleeping for 10 seconds after reboot before starting backup..."
	sleep 10
fi

# if there's a lock, abort now
if [ -f "$BACKUP_DIR/$BACKUP_LOCK" ]; then
	echo "File '$BACKUP_DIR/$BACKUP_LOCK' exists, aborting."
	exit 2
fi

touch "$BACKUP_DIR/$BACKUP_LOCK"

echo "Syncing files to backup directory ..."
nice ionice -c3 rsync \
		--verbose --archive --recursive --human-readable \
		--hard-links --delete --one-file-system \
		--include-from="$INCLUDE_FILE" \
		--exclude-from="$EXCLUDE_FILE" \
		/ "$BACKUP_DIR/$ACTIVE_BACKUP"
touch "$BACKUP_DIR/$ACTIVE_BACKUP"

echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

# remove lock
rm --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK"

