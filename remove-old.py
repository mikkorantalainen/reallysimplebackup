#!/usr/bin/python

import os, os.path, sys, shutil
from datetime import datetime, timedelta
 
verbose = 1 # verbosity level: 0 - 4, default 1
MIN_DAYS_TO_KEEP = 0
MIN_DIRS_TO_KEEP = 2
DATE_FORMAT = "%Y%m%dT%H%M%S"
DIRNAME_MAX_ERROR_MINUTES = 75 # one hour for daylight saving time plus 15 minutes for the backup
MIN_REVISION_DELTA_MINUTES = 1 # the minimum difference in minutes between two saved revisions
 
# List all direcotry contents
listing = os.listdir(sys.argv[1])
# TODO: figure out if the listing is safe if the current working directory is not the parent directory 
 
# alphabetical order is date order, so sort by date:
listing.sort(reverse=True) 
 
oldest_date = datetime.now() - timedelta(days=MIN_DAYS_TO_KEEP)
kept_dirs_count = 0
removed_dirs_count = 0
ignored_count = 0

min_delta_to_previous = timedelta(minutes=MIN_REVISION_DELTA_MINUTES)
previous_kept_datetime = datetime.max # use previous (newer) time as maximum value to keep the first one always

for name in listing:
	if verbose >= 3:
		print "Checking \""+name+"\"..."
	if not os.path.isdir(name): # look for directories only
		if verbose >= 2:
			print "Ignoring \""+name+"\" (not a directory)."
		ignored_count += 1
	else: # 'name' is directory
		try:
			# Parses the directory name and get a date out of it:
			name_date = datetime.strptime(name, DATE_FORMAT)
		except ValueError: # Ignore directories that do match the date pattern
			if verbose >= 2:
				print "Ignoring \""+name+"\" (did not match format " + DATE_FORMAT + ")."
			ignored_count += 1
			continue
			
		# we'll use filesystem stat as the correct time, the name is used for confirmation only
		stat_date = datetime.fromtimestamp(os.stat(name).st_mtime);

		if abs(name_date - stat_date) > timedelta(minutes=DIRNAME_MAX_ERROR_MINUTES):
			if verbose >= 2:
				print "Ignoring "+name+" because its timestamp is too far from its name."
			if verbose >= 3:
				print "Difference was %s and limit was %s" % (abs(name_date - stat_date), timedelta(minutes=DIRNAME_MAX_ERROR_MINUTES))
			ignored_count += 1
			continue
 
		if verbose >= 3 and previous_kept_datetime < datetime.max:
			print "Difference to already kept backup: %s." % (previous_kept_datetime - stat_date)

		# Keeps directories newer than MIN_MONTHS_TO_KEEP months with a
		# minimum of MIN_DIRS_TO_KEEP directories kept
		#if name_date >= oldest_date or kept_dirs_count < MIN_DIRS_TO_KEEP:
		if stat_date < previous_kept_datetime - min_delta_to_previous:
			if verbose:
				print "Keeping directory \""+name+"\"."
			# update book keeping
			previous_kept_datetime = stat_date;
			min_delta_to_previous *= 2; # double the minimum time for the next revision
			kept_dirs_count += 1
			if verbose >= 3:
				print "Minimum delta to previous version is now %s." % (min_delta_to_previous)
		else:
			if verbose:
				print "Removing \""+name+"\" ..."
			removed_dirs_count += 1
			print "SHUTIL.RMTREE() DISABLED FOR TESTING"
			#shutil.rmtree(name)

if verbose:
	print "Statistics:"
	print "Removed "+str(removed_dirs_count)+" directories"
	print "Kept "+str(kept_dirs_count)+" directories"
	print "Ignored "+str(ignored_count)+" directory entries"

