#!/usr/bin/python3 -Wall
# See also: https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt
"""
reallysimplebackup-rsync-with-private-binds

Python script to create backup of the whole system using private bind mount
of actual storage of currently mounted filesystems instead of normal
filesystem view. This allows side-stepping problems with bind mounts, encrypted
partitions, nested filesystems etc.

Copyright (c) 2019 Mikko Rantalainen <mikko.rantalainen@iki.fi>
License: MIT X License
"""

import subprocess
import sys
import re
import tempfile
import os
import argparse

#from argparse import ArgumentParser

parser = argparse.ArgumentParser()
parser.add_argument(
	"-d", "--debug",
	dest = "debug",
	action = "store_true",
	help = "turn on debug messages",
	)

parser.add_argument(
	"-b", "--backup-dir",
	dest = "backup_dir",
	default = "/backup/auto",
	help = "container directory for backups (rotated backups appear here)",
	metavar = "BACKUPS_DIR",
	)

parser.add_argument(
	"-t", "--target",
	dest = "target",
	default = "/backup/auto/latest.new",
	help = "target directory for latest backup",
	metavar = "TARGET_DIR",
	)

parser.add_argument(
	"-p", "--prefix",
	dest = "prefix",
	default = "realtime-partition-backup-",
	help = "prefix to temporary directory for private bind mounts",
	nargs = 1,
	metavar = "PREFIX",
	)

parser.add_argument(
	"-i", "--include-from",
	dest = "include_from",
	default = "/dev/null",
	help = "value to be passed to rsync --include-from",
	nargs = 1,
	metavar = "FILE",
	)

parser.add_argument(
	"-x", "--exclude-from",
	dest = "exclude_from",
	default = "/dev/null",
	help = "value to be passed to rsync --exclude-from",
	nargs = 1,
	metavar = "FILE",
	)

parser.add_argument(
	nargs = argparse.REMAINDER,
	dest = "extra_args",
	help = "extra arguments to be passed to rsync",
	)

#parser.add_argument(
#	"dirs",
#	nargs = "+",
#	help = "one or more additional directory names to rsync",
#	metavar = "DIR",
#	)

config = parser.parse_args()

# FIXME: debug only
if config.debug:
	print("Config=", config)
	print("str(os.path.abspath(config.target))=", str(os.path.abspath(config.target)))

if config.extra_args:
	separator = config.extra_args.pop(0) # first extra argument should always be "--" and we want to ignore it
	if separator != "--":
		raise RuntimeError("Extra arguments must start with a '--'")

rsync_command = [
	"rsync",
	"--verbose",
	"--archive",
	"--recursive",
	"--human-readable",
	"--hard-links",
	"--delete",
	"--dry-run", # FIXME: only for debugging
	"--include-from",
	config.include_from,
	"--exclude-from",
	config.exclude_from,
]


if not config.target.startswith(config.backup_dir) or config.backup_dir == config.target:
	sys.stderr.write("error: value of --target must start with value of --backup-dir, exiting.\n")
	sys.stderr.write("value of --backup-dir: "+str(config.backup_dir)+"\n")
	sys.stderr.write("value of --target: "+str(config.target)+"\n")
	sys.exit(2)
	
#for dir in config.dirs:
#	rsync_command.append(dir)
#rsync_command.append(config.target)

#print(rsync_command)
#sys.exit(1)

DEBUG = config.debug
BACKUP_TARGET = "/backup/auto"
PREFIX_FOR_BIND_MOUNTS = "realtime-partition-backup-"
PREFIX_FOR_MOUNTED_MEDIA = "/media/"

def W(s): # warning messages
	'''Print a warning message to stderr'''
	sys.stderr.write("\033[31m"+s+"\033[0m")
	return

def S(s): # status messages
	'''Print a status message to stdout'''
	sys.stdout.write(s)
	return

def D(s): # debug messages
	'''Maybe print a debug message to stdout (debug messages)'''
	if DEBUG:
		sys.stdout.write(s)
		sys.stdout.flush()
	return

def system_arg_quote(s):
	'''Escape given string as command line argument (note that the process name may require different quotation, this is stricly about arguments to the command)'''
	return "'" + s.replace("'", "'\"'\"'") + "'"

def system(args):
	'''Run a process similar to os.system() with improved checks (require status=0, empty stderr), return stdout'''
	D("Executing "+str(args)+"\n")
	process_results = subprocess.run(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	status = process_results.returncode
	errors = process_results.stderr.decode("utf-8")
	output = process_results.stdout.decode("utf-8")
	if errors != "" or status != 0:
		sys.stderr.write("Failed to run command: (status code: "+str(status)+"): " + str(args)+"\nstderr: " + str(errors)+"\nstdout:" + str(output)+"\n")
		sys.exit(1)
	return output

def detect_mounts_to_backup(backup_location):
	'''Get list of mount points that we really want to backup, return array where each item is an array[mountpoint, label]'''
	rv = [] # result buffer

	fstypes_to_skip = (
		"sysfs",
		"proc",
		"devpts",
		"devtmpfs",
		"squashfs",
		"tmpfs",
		"nsfs",
		"fuse.gvfsd-fuse",
		"fuse.sshfs",
		"ecryptfs",
		"cgroup",
		"cgroup2",
		"securityfs",
		"pstore",
		"autofs",
		"hugetlbfs",
		"debugfs",
		"mqueue",
		"configfs",
		"fusectl",
		"tracefs",
		"binfmt_misc",
	)

	output = system(["findmnt", "--raw", "--noheadings", "--output", "fstype,source,target"])

	for line in iter(output.splitlines()):
		fstype, source, mountpoint = line.split(" ")

		if any(fstype in s for s in fstypes_to_skip):
			D("SKIPPING (fstype): "+line+"\n")
			continue

		# filter out any dir that contains substring PREFIX_FOR_BIND_MOUNTS (prefix for mkdtemp)
		if PREFIX_FOR_BIND_MOUNTS in mountpoint:
			D("SKIPPING (bind mount): "+line+"\n")
			continue

		# filter out any dir that contains substring PREFIX_FOR_MOUNTED_MEDIA (prefix for dynamically mounted disks including external backup)
		if mountpoint.startswith(PREFIX_FOR_MOUNTED_MEDIA):
			D("SKIPPING (media mount): "+line+"\n")
			continue

		if source.endswith("]"):
			D("SKIPPING (bind mount): "+line+"\n")
			continue

		label = mountpoint
		label = re.sub(r"^/", r"", label) # remove slash at the start of the mountpoint
		label = label.replace("/", "_") # replace remaining all slashes with underscores
		if label == "": # check if label is now empty string
			label = "root"

		if label != "root" and backup_location.startswith(mountpoint):
			D("SKIPPING (backup location): "+line+"\n")
			continue

		D("ACCEPTED INPUT: " + line + "\n")
		D("--> Will bind "+mountpoint+" (source:"+source+") to '"+label+"'\n")

		rv.append([mountpoint, label])

	return rv

def sanity_check_mounts(mounts):
	'''Check if mounts (array returned by detect_mounts_to_backup()) looks sane enough to do the backup (verify that auto detection has not found anything problematic)'''
	already_seen_labels = {}
	for mountdata in mounts:
		mountpoint, label = mountdata
		if label in already_seen_labels:
			raise RuntimeError("Label '"+label+"' (mountpoint="+mountpoint+") seen at least twice in mount labels, aborting")
		already_seen_labels[label] = 1

	# FIXME: extra sanity check for testing, remove when not needed anymore
	assert len(already_seen_labels) == 2, "Expected to see exactly 2 labels, mounts="+str(mounts)+" len="+str(len(already_seen_labels))
	assert "root" in already_seen_labels, "Expected to see label 'root'"
	assert "data" in already_seen_labels, "Expected to see label 'data'"
	# everything seems to be okay

def backup():
	'''Bind mount all partitions needing a backup, do the backup and finally tear down the bind mounts'''
	# Collect commands to teardown the filesystem level changes, note that this list is expected to be run in order so we must insert commands to be run first at the start of the list below
	teardown_commands = []
	try:
		tmpdir = tempfile.mkdtemp(prefix=PREFIX_FOR_BIND_MOUNTS)
		teardown_commands.insert(0, ["rmdir", "--", tmpdir])

		mounts = detect_mounts_to_backup(BACKUP_TARGET)
		sanity_check_mounts(mounts)

		for mountdata in mounts:
			mountpoint, label = mountdata
			D("mountpoint="+mountpoint+" label="+label+"\n")
			mounttarget = str(tmpdir+"/"+label)
			# mount mountpoint to mounttarget with private bind
			system(["mkdir", "--", mounttarget])
			teardown_commands.insert(0, ["rmdir", "--", mounttarget])

			system(["mount", "-o", "bind,ro", "--make-private", "--make-unbindable", mountpoint, mounttarget])
			teardown_commands.insert(0, ["umount", mounttarget])

		# TODO: do the backup
		rsync_command.append(tmpdir+"/.")
		rsync_command.append(config.target+"/.")
		print("TODO: Would run rsync_command=", rsync_command)
		print("# time "+(" ".join(rsync_command)))

		# FIXME: remove HACK: start a shell to allow manual backup
		W("Warning: backup is currently implemented as interactive bash shell (CTRL+D to continue):\n")
		#S("Hint: rsync -avH --delete --dry-run '"+tmpdir+"/.' '"+BACKUP_TARGET+"/latest.new/.'\n")
		os.system("cd "+system_arg_quote(tmpdir)+" && PS1='\\u@\\h:\\w (\\[\\033[01;33m\\]backup\\[\\033[00m\\])\\$ ' bash --norc")

	finally:
		for command in teardown_commands:
			system(command)


##############################################################################
backup()
sys.exit(0)
##############################################################################

