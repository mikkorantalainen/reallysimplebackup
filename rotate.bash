#!/bin/bash
# run rsync niced and ioniced to idle IO levels

# config:
source "/usr/local/etc/backup-config"

# rotate backup
cd "$BACKUP_DIR"
echo "Rotating backup ..."
echo "Copying '$ACTIVE_BACKUP' to '$BACKUP_NAME' ..."
nice ionice -c3 cp -al "$ACTIVE_BACKUP" "$BACKUP_NAME"
echo "Hardlinking duplicate files ..."
# allow up to 0.5 GB of memory to be used for hardlinking
ulimit -S -m 500000 -t 600
# perhaps add "--ignore-time" flag to following to link more files together
nice ionice -c3 hardlink --verbose --maximize "$ACTIVE_BACKUP" "$BACKUP_NAME"
echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

