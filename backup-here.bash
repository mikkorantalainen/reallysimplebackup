#!/bin/bash
# run rsync of the latest backup niced and ioniced to idle IO levels

# config:
source "/etc/reallysimplebackup/config" || exit 10

TARGET=$(dirname "$0")
TARGET="$TARGET/backup"

if [ "$1" = "--init" ]; then
	echo "Creating directory '$TARGET/$ACTIVE_BACKUP'"
	mkdir -p "$TARGET/$ACTIVE_BACKUP"
	echo "Re-run this script without the --init parameter to create backup"
	exit 0
fi

if [ ! -d "$TARGET/$ACTIVE_BACKUP" ]; then
	echo "Target directory '$TARGET/$ACTIVE_BACKUP' does not exist, aborting"
	exit 9
fi

echo "TESTING - ABORTING"
exit # TESTING ONLY



# the script:

echo "Syncing backup ..."
echo "Source: \"$BACKUP_DIR/$ACTIVE_BACKUP\""
echo "Target: \"$TARGET\""
mkdir -p "$TARGET"
#gksudo --description "Backup to usb media" -- nice ionice -c3 rsync --dry-run \
#		--verbose --archive --recursive --human-readable \
#		--hard-links --delete --one-file-system \
#		"$BACKUP_DIR/$ACTIVE_BACKUP" "$TARGET"
#
gksudo --message "Enter password to synchronize backup to usb media" -- nice ionice -c3 rsync \
		--verbose --archive --recursive --human-readable \
		--hard-links --delete --one-file-system \
		"$BACKUP_DIR/$ACTIVE_BACKUP" "$TARGET"

gksudo --message "Enter password to update timestamp of usb media" -- touch "$TARGET"

# revoke sudo permissions
sudo -k

echo ""
echo "Backup disk usage after backup:"
df -h "$TARGET"


