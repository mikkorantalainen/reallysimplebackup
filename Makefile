# Basic pathes
PREFIX  ?= usr
BINDIR  ?= $(PREFIX)/bin
ETCDIR  ?= etc
LIBDIR  ?= lib
MANDIR  ?= $(PREFIX)/share/man
SHAREDIR ?= $(PREFIX)/share

# Complete the path names
BINDIR  := $(DESTDIR)/$(BINDIR)
LIBDIR  := $(DESTDIR)/$(LIBDIR)
CONFDIR := $(DESTDIR)/$(ETCDIR)/reallysimplebackup
CRONDIR := $(DESTDIR)/$(ETCDIR)/cron.d
MANDIR  := $(DESTDIR)/$(MANDIR)
# Note that ETCDIR is used by other paths above, it must be overwritten last:
ETCDIR  := $(DESTDIR)/$(ETCDIR)
SHAREDIR := $(DESTDIR)/$(SHAREDIR)

default:
	@echo "Usage: make <target>, possible targets:"
	@egrep '^[-a-z]+:' Makefile | sed 's/^/- /; s/://' || true

install:
	install -D -o root -g root -m 755 rotate.bash $(BINDIR)/reallysimplebackup-rotate
	install -D -o root -g root -m 755 rsync.bash $(BINDIR)/reallysimplebackup-rsync
	install -D -o root -g root -m 755 backup-here.bash $(BINDIR)/reallysimplebackup-backup-here
	install -D -o root -g root -m 755 list-old-print0.py $(BINDIR)/reallysimplebackup-list-old-print0

	install -D -o root -g root -m 644 config.bash $(CONFDIR)/config
	install -D -o root -g root -m 644 rsync-include $(CONFDIR)/include
	install -D -o root -g root -m 644 rsync-exclude $(CONFDIR)/exclude
	install -D -o root -g root -m 644 logrotate $(ETCDIR)/logrotate.d/reallysimplebackup

	#install -D -o root -g root -m 644 reallysimplebackup.cron $(CRONDIR)/reallysimplebackup
	install -D -o root -g root -m 644 reallysimplebackup.1  $(MANDIR)/man1/reallysimplebackup-rsync.1
	gzip -9n $(MANDIR)/man1/reallysimplebackup-rsync.1
	ln -s reallysimplebackup.1.gz $(MANDIR)/man1/reallysimplebackup-rotate.1.gz
	ln -s reallysimplebackup.1.gz $(MANDIR)/man1/reallysimplebackup-backup-here.1.gz
	ln -s reallysimplebackup.1.gz $(MANDIR)/man1/reallysimplebackup-list-old-print0.1.gz

	install -D -o root -g root -m 644 reallysimplebackup-rsync.service $(LIBDIR)/systemd/system/reallysimplebackup-rsync.service
	install -D -o root -g root -m 644 reallysimplebackup-cleanup-lockfiles.service $(LIBDIR)/systemd/system/reallysimplebackup-cleanup-lockfiles.service
	install -D -o root -g root -m 644 reallysimplebackup-rsync.timer $(LIBDIR)/systemd/system/reallysimplebackup-rsync.timer

	install -D -o root -g root -m 644 lintian.overrides $(SHAREDIR)/lintian/overrides/reallysimplebackup


clean:
	rm -f *~

ppa-deb:
	debuild -i -S -j`getconf _NPROCESSORS_ONLN` --lintian-opts --pedantic

deb:
	debuild -I -E -us -uc -j`getconf _NPROCESSORS_ONLN` --lintian-opts --pedantic -i -I -E

deb-sign:
	debuild -I -E -j`getconf _NPROCESSORS_ONLN` --lintian-opts --pedantic -i -I -E

release:
	dch -i
	debchange --release

