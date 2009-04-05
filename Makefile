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

all:

install:
	install -D -o root -g root -m 755 rotate.bash $(BINDIR)/reallysimplebackup-rotate
	install -D -o root -g root -m 755 rsync.bash $(BINDIR)/reallysimplebackup-rsync

	install -D -o root -g root -m 644 config.bash $(CONFDIR)/config
	install -D -o root -g root -m 644 rsync-include $(CONFDIR)/include
	install -D -o root -g root -m 644 rsync-exclude $(CONFDIR)/exclude

	install -D -o root -g root -m 644 reallysimplebackup.cron $(CRONDIR)/reallysimplebackup
	install -D -o root -g root -m 644 reallysimplebackup.1  $(MANDIR)/man1/reallysimplebackup.1
	ln -s reallysimplebackup.1 $(MANDIR)/man1/reallysimplebackup-rsync.1
	ln -s reallysimplebackup.1 $(MANDIR)/man1/reallysimplebackup-rotate.1

clean:
	rm -f *~

deb:
	debuild -i -E -us -uc -j2 --lintian-opts --pedantic -i -I -E

deb-sign:
	debuild -i -E -j2 --lintian-opts --pedantic -i -I -E

