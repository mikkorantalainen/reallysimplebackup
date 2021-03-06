# Basic pathes
PREFIX  ?= usr
BINDIR  ?= $(PREFIX)/bin
ETCDIR  ?= etc
MANDIR  ?= $(PREFIX)/share/man

# Complete the path names
BINDIR  := $(DESTDIR)/$(BINDIR)
CONFDIR := $(DESTDIR)/$(ETCDIR)/reallysimplebackup
CRONDIR := $(DESTDIR)/$(ETCDIR)/cron.d
MANDIR  := $(DESTDIR)/$(MANDIR)

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

	install -D -o root -g root -m 644 reallysimplebackup.cron $(CRONDIR)/reallysimplebackup
	install -D -o root -g root -m 644 reallysimplebackup.1  $(MANDIR)/man1/reallysimplebackup.1
	ln -s reallysimplebackup.1 $(MANDIR)/man1/reallysimplebackup-rsync.1
	ln -s reallysimplebackup.1 $(MANDIR)/man1/reallysimplebackup-rotate.1
	ln -s reallysimplebackup.1 $(MANDIR)/man1/reallysimplebackup-backup-here.1
	ln -s reallysimplebackup.1 $(MANDIR)/man1/reallysimplebackup-list-old-print0.1

clean:
	rm -f *~

ppa-deb:
	debuild -i -S -j`getconf _NPROCESSORS_ONLN` --lintian-opts --pedantic

deb:
	debuild -I -E -us -uc -j`getconf _NPROCESSORS_ONLN` --lintian-opts --pedantic -i -I -E

deb-sign:
	debuild -I -E -j`getconf _NPROCESSORS_ONLN` --lintian-opts --pedantic -i -I -E

release:
	debchange --release

