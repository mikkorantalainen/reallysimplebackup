#!/usr/bin/python3
# 
# Iterates through the current directory looking for specially named
# directories and keeps exponentially older versions - the directories
# that should be removed are printed to standard output separated with
# null bytes (suitable for passing to "xargs -0 rm --one-file-system-rf --")
#
# TODO: add some switches to change behavior: the current behavior would be
#	"--print0 --print-deprecated", additional features could be
#	"--print-oldest" (for removing the oldest version if disk space is low,
#	"--min-keeping-time=DAYS" (to specify safe days before a backup is
#	considered redundant
# TODO: allow looking at some other directory but current
#
import os, os.path, sys, shutil
from datetime import datetime, timedelta
 
verbose = 2 # verbosity level: 0 - 4, default 1
DATE_FORMAT = "%Y%m%dT%H%M%S"
DIRNAME_MAX_ERROR_MINUTES = 75 # one hour for daylight saving time plus 15 minutes for the backup
MIN_REVISION_DELTA_MINUTES = 1 # the minimum difference in minutes between two saved revisions (initial value)
OUTPUT_NAME_SEPARATOR = "\x00" # reasonable choices are "\x00" and "\n"
 
# List all directory contents of current directory (perhaps we someday will support sys.argv[1] here?)
listing = os.listdir(".")
# TODO: figure out if the listing is safe if the current working directory is not the parent directory 
 
# alphabetical order is date order, so sort by date:
listing.sort(reverse=True) 
 
kept_dirs_count = 0
removed_dirs_count = 0
ignored_count = 0

min_delta_to_previous = timedelta(minutes=MIN_REVISION_DELTA_MINUTES)
previous_kept_datetime = datetime.max # use previous (newer) time as maximum value to keep the first one always

for name in listing:
	if verbose >= 3:
		print("Checking \""+name+"\"...", file=sys.stderr)
	if not os.path.isdir(name): # look for directories only
		if verbose >= 2:
			print("Ignoring \""+name+"\" (not a directory).", file=sys.stderr)
		ignored_count += 1
	else: # 'name' is directory
		try:
			# Parses the directory name and get a date out of it:
			name_date = datetime.strptime(name, DATE_FORMAT)
		except ValueError: # Ignore directories that do match the date pattern
			if verbose >= 2:
				print("Ignoring \""+name+"\" (did not match format " + DATE_FORMAT + ").", file=sys.stderr)
			ignored_count += 1
			continue
			
		# we'll use filesystem stat as the correct time, the name is used for confirmation only
		stat_date = datetime.fromtimestamp(os.stat(name).st_mtime);

		if abs(name_date - stat_date) > timedelta(minutes=DIRNAME_MAX_ERROR_MINUTES):
			if verbose >= 2:
				print("Ignoring "+name+" because its timestamp is too far from its name.", file=sys.stderr)
			if verbose >= 3:
				print("Difference was %s and limit was %s" % (abs(name_date - stat_date), timedelta(minutes=DIRNAME_MAX_ERROR_MINUTES)), file=sys.stderr)
			ignored_count += 1
			continue
 
		if verbose >= 3 and previous_kept_datetime < datetime.max:
			print("Difference to already kept backup: %s." % (previous_kept_datetime - stat_date), file=sys.stderr)

		if stat_date < previous_kept_datetime - min_delta_to_previous:
			if verbose:
				print("Keeping directory \""+name+"\".", file=sys.stderr)
			# update book keeping
			previous_kept_datetime = stat_date;
			min_delta_to_previous *= 2; # double the minimum time for the next revision
			# limit maximum delta a bit under 1 year
			if min_delta_to_previous > timedelta(days=360):
				min_delta_to_previous = timedelta(days=360)
			kept_dirs_count += 1
			if verbose >= 3:
				print("Minimum delta to previous version is now %s." % (min_delta_to_previous), file=sys.stderr)
		else: # redundant directory
			if verbose:
				print("Removing \""+name+"\" ...", file=sys.stderr)
			removed_dirs_count += 1
			print("" + name + OUTPUT_NAME_SEPARATOR, end="")
			#sys.stdout.write("") # reset the "print statement prints space and or newline between stuff" magic
			sys.stdout.flush()
			#print "SHUTIL.RMTREE() DISABLED FOR TESTING"
			#shutil.rmtree(name)
			# for other possibilities, see for example: http://code.activestate.com/recipes/193736/

if verbose:
	print("Statistics:", file=sys.stderr)
	print("Removed "+str(removed_dirs_count)+" directories", file=sys.stderr)
	print("Kept "+str(kept_dirs_count)+" directories", file=sys.stderr)
	print("Ignored "+str(ignored_count)+" directory entries", file=sys.stderr)

