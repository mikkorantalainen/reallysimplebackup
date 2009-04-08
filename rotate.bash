#!/bin/bash
# run rsync niced and ioniced to idle IO levels

# config:
source "/etc/reallysimplebackup/config"

# rotate backup
cd "$BACKUP_DIR"
echo "Rotating backup ..."
echo "Copying '$ACTIVE_BACKUP' to '$BACKUP_NAME' ..."
nice ionice -c3 cp -al "$ACTIVE_BACKUP" "$BACKUP_NAME"
echo "Hardlinking duplicate files ..."
# allow up to 0.5 GB of memory to be used for hardlinking
ulimit -S -m 500000 -t 600
# TODO: remove old backup revisions
# TODO: improve hardlinking:
# 	perhaps add "--ignore-time" flag to following to link more files together
#	get last two latest directories and hardlink between those
#nice ionice -c3 hardlink --verbose --maximize --respect-name */
echo "DEBUG: HARDLINK rotate step has been disabled to increase performance."
echo ""
echo "Backup disk usage after backup:"
df -h "$BACKUP_DIR/."

