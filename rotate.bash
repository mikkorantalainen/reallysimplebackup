#!/bin/bash
# run rsync niced and ioniced to idle IO levels

# config:
source "/etc/reallysimplebackup/config" || exit 10

# rotate backup
cd "$BACKUP_DIR"
echo "Rotating backup ..."
echo "Copying '$ACTIVE_BACKUP' to '$BACKUP_NAME.tmp' ..."
nice ionice -c3 cp -al "$ACTIVE_BACKUP" "$BACKUP_NAME.tmp"
echo "Completed copying, renaming to final name: $BACKUP_NAME"
mv "$BACKUP_NAME.tmp" "$BACKUP_NAME"

echo "Hardlinking duplicate files ..."
# allow up to 0.5 GB of memory to be used for hardlinking
#ulimit -S -m 500000 -t 600
# get latest directories and hardlink between those
nice ionice -c3 hardlink --verbose --maximize --respect-name $(ls -d -c */ | head -3)

echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

echo ""
echo "Removing deprecated backups ..."
(reallysimplebackup-list-old-print0 | xargs -0 --no-run-if-empty rm --one-file-system -rf --) 2>&1

