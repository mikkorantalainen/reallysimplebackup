#!/bin/bash
# run rsync niced and ioniced to idle IO levels

# config:
source "/etc/reallysimplebackup/config" || exit 10

# rotate backup
cd "$BACKUP_DIR" || exit 1

# in case files are moved around after the last rotated backup, hardlink latest copy with the older copy
echo "Hardlinking duplicate files ..."
# allow up to 0.5 GB of memory to be used for hardlinking
#ulimit -S -m 500000 -t 600
# get latest directories and hardlink between those
# ext4 is able to store files smaller than 160 bytes inline so skip small files
# https://ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout#Inline_Data
nice ionice -c3 hardlink --verbose --maximize --minimum-size=161 --respect-name $(ls -d -c */ | head -2)

echo "Rotating backup ..."
echo "Copying '$ACTIVE_BACKUP' to '$BACKUP_NAME.tmp' ..."
nice ionice -c3 nocache cp -al "$ACTIVE_BACKUP" "$BACKUP_NAME.tmp" || exit 2
echo "Completed copying, renaming to final name: $BACKUP_NAME"
mv "$BACKUP_NAME.tmp" "$BACKUP_NAME" || exit 3


echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

echo ""
echo "Removing deprecated backups ..."
(reallysimplebackup-list-old-print0 | xargs -0 --no-run-if-empty rm --one-file-system -rf --) 2>&1

