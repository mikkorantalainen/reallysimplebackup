#!/bin/bash
# run rsync the whole system niced and ioniced to idle IO levels
#
# Note that effective ionice requires using cfq or bfq scheduler in Linux
# because other disc schedulers do not implement IO levels.
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
	echo "Cleaning lock file after reboot and quitting..."
	rm  --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK" || exit 4
	exit 0
fi

# if there's a lock, abort now
if [ -f "$BACKUP_DIR/$BACKUP_LOCK" ]; then
	echo "File '$BACKUP_DIR/$BACKUP_LOCK' exists, aborting."
	exit 2
fi

touch "$BACKUP_DIR/$BACKUP_LOCK" || exit 4

# best effort remove partial rotates
(cd "$BACKUP_DIR" && find . -maxdepth 1 -regextype egrep -regex "^[.]/[0-9]{8}T[0-9]{6}.tmp" -exec rm -rf --one-file-system -- {} +) &

perfrun()
{
	/usr/bin/time -f "Elapsed: %E Major faults: %F I/O: %I MEM: %MK CPU: %P" "$@"
}

echo "Syncing files to backup directory ..."
perfrun nice ionice -c3 rsync $RSYNC_EXTRA_FLAGS \
		--verbose --archive --recursive --human-readable \
		--delete \
		--include-from="$INCLUDE_FILE" \
		--exclude-from="$EXCLUDE_FILE" \
		/. "$BACKUP_DIR/$ACTIVE_BACKUP/."
STATUS=$?
touch "$BACKUP_DIR/$ACTIVE_BACKUP"

case "$STATUS" in
	0)
		echo "Sync completed successfully."
		;;
	24)
		echo "Assuming sync completed successfully (rsync exit value: $STATUS)"
		;;
	*)
		echo "Sync failed (rsync exit value: $STATUS). Aborting..."
		# remove lock
		rm --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK"
		date +"%Y-%m-%d %H:%M:%S: Aborted backup synchronization."
		exit 66
		;;
esac

echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

FRESH_TIMESTAMP="$(find "$BACKUP_DIR/$BACKUP_ROTATE_TIMESTAMP" -mmin -1440)"

if test -z "$FRESH_TIMESTAMP"; then
	touch "$BACKUP_DIR/$BACKUP_ROTATE_TIMESTAMP"
	echo ""
	echo "Rotating backups..."
	echo ""
	perfrun /usr/bin/reallysimplebackup-rotate || echo "Warning: rotate failed."
	touch "$BACKUP_DIR/$BACKUP_ROTATE_TIMESTAMP"
else
	echo "Last rotate was done less than 24h ago, skipping rotate."
fi

# remove lock
rm --interactive=never -- "$BACKUP_DIR/$BACKUP_LOCK"

date +"%Y-%m-%d %H:%M:%S: Done backup synchronization."

