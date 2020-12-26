#!/bin/bash
# run rsync the whole system niced and ioniced to idle IO levels
#

SLEEP_AFTER_REBOOT=120s

date +"%Y-%m-%d %H:%M:%S: Starting backup synchronization ..."

# config:
source "/etc/reallysimplebackup/config" || exit 10

if test -z "$BACKUP_DIR" -o -z "$ACTIVE_BACKUP"; then
	echo "Error: config values BACKUP_DIR and ACTIVE_BACKUP must be non-empty strings."
	exit 1
fi

if [ "$ACTIVE_BACKUP" = "" ]; then
	echo "Failed to source sensible ACTIVE_BACKUP variable, aborting."
	exit 10
fi

if [ ! -d "$BACKUP_DIR/$ACTIVE_BACKUP" ]; then
	echo "Target directory '$BACKUP_DIR/$ACTIVE_BACKUP' does not exist, aborting."
	exit 3
fi

if [ "$1" = "after-reboot" ]; then
	touch "$BACKUP_DIR/$BACKUP_LOCK"
	echo "Sleeping for $SLEEP_AFTER_REBOOT after reboot before starting backup..."
	sleep "$SLEEP_AFTER_REBOOT"
	rm  --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK"
fi

# if there's a lock, abort now
if [ -f "$BACKUP_DIR/$BACKUP_LOCK" ]; then
	echo "File '$BACKUP_DIR/$BACKUP_LOCK' exists, aborting."
	exit 2
fi

touch "$BACKUP_DIR/$BACKUP_LOCK"

perfrun()
{
	/usr/bin/time -f "Elapsed: %E Major faults: %F I/O: %I MEM: %MK CPU: %P" "$@"
}

echo "Syncing files to backup directory ..."
perfrun nice ionice -c3 rsync $RSYNC_EXTRA_FLAGS \
		--verbose --archive --recursive --human-readable \
		--hard-links --delete \
		--include-from="$INCLUDE_FILE" \
		--exclude-from="$EXCLUDE_FILE" \
		/. "$BACKUP_DIR/$ACTIVE_BACKUP/."
touch "$BACKUP_DIR/$ACTIVE_BACKUP"

echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

FRESH_ROTATES=$(cd "$BACKUP_DIR"; find . -maxdepth 1 -type d -mmin -360 -a -not -name "." -a -not -name "$ACTIVE_BACKUP")

if [ "$FRESH_ROTATES" = "" ]; then
	echo ""
	echo "Latest rotated backup is old, latest backup will be rotated."
	echo ""
	perfrun /usr/bin/reallysimplebackup-rotate
fi

# remove lock
rm --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK"

date +"%Y-%m-%d %H:%M:%S: Done backup synchronization."

