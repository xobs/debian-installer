#!/usr/bin/make -f
#
# Debian Installer system makefile.
# Copyright 2001 by Joey Hess <joeyh@debian.org>.
# Licensed under the terms of the GPL.
#
# This makefile builds a debian-installer system from a collection of
# udebs.

# The type of system to build. Determines what udebs are unpacked into
# the system. See the .list files for various types. You may want to
# override this on the command line.
TYPE=net

# List here any extra udebs that are not in the list file but that
# should still be included on the system.
EXTRAS=""

# Build tree location.
DEST=debian-installer

# Directory apt uses for stuff.
APTDIR=apt

# Directory udebs are placed in.
UDEBDIR=udebs

# Local directory that is searched for udebs, to avoid downloading.
# (Or for udebs that are not yet available for download.)
LOCALUDEBDIR=localudebs

# Figure out which sources.list to use. The .local one is preferred,
# so you can set up a locally preferred one (and not accidentially cvs
# commit it).
ifeq ($(wildcard sources.list.local),sources.list.local)
SOURCES_LIST=sources.list.local
else
SOURCES_LIST=sources.list
endif

# All these options makes apt read the right sources list, and
# use APTDIR for everything so it need not run as root.
APT_GET=apt-get --assume-yes \
	-o Dir::Etc::sourcelist=./$(SOURCES_LIST) \
	-o Dir::State=$(APTDIR)/state \
	-o Debug::NoLocking=true \
	-o Dir::Cache=$(APTDIR)/cache

# Comments are allowed in the lists.
UDEBS=$(shell grep --no-filename -v ^\# lists/base lists/$(TYPE)) $(EXTRAS)

DPKGDIR=$(DEST)/var/lib/dpkg

build: demo_clean tree lib_reduce status_reduce stats

# For now, just build a demo tarball. Later, this should build actual bootable
# images.
image: build
	tar czf ../debian-installer.tar.gz $(DEST)

demo:
	mkdir -p $(DEST)/proc 
	sudo chroot $(DEST) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(DEST) bin/sh -c "export DEBCONF_FRONTEND=text DEBCONF_DEBUG=5; /usr/bin/debconf-loadtemplate /var/lib/dpkg/info/*.templates; /usr/share/debconf/frontend /usr/bin/main-menu"

shell:
	sudo chroot $(DEST) bin/sh

demo_clean:
	-if [ -e $(DEST)/proc/self ]; then \
		sudo chroot $(DEST) bin/sh -c "if mount | grep ^proc ; then bin/umount /proc ; fi" &> /dev/null; \
		sudo chroot $(DEST) bin/sh -c "rm -rf /etc /var"; \
	fi

clean:
	dh_clean
	rm -rf $(DEST) $(APTDIR) $(UDEBDIR)

# Get all required udebs and put in UDEBDIR.
get_udebs:
	mkdir -p $(APTDIR)/state/lists/partial
	mkdir -p $(APTDIR)/cache/archives/partial
	$(APT_GET) update
	$(APT_GET) autoclean
	# If there are local udebs, remove them from the list of things to
	# get. Then get all the udebs that are left to get.
	needed="$(UDEBS)"; \
	for file in `find $(LOCALUDEBDIR) -type f -name "*_*" -printf "%f\n" 2>/dev/null`; do \
		package=`echo $$file | cut -d _ -f 1`; \
		needed=`echo $$needed | sed "s/$$package *//"`; \
	done; \
	$(APT_GET) -dy install $$needed
	# Now the udebs are in APTDIR/cache/archives/ and maybe LOCALUDEBDIR,
	# but there may be other udebs there too besides those we asked for.
	# So link those we asked for to UDEBDIR, renaming them to more useful
	# names.
	rm -rf $(UDEBDIR)
	mkdir -p $(UDEBDIR)
	for package in $(UDEBS); do \
		if [ -e $(APTDIR)/cache/archives/$$package\_* ]; then \
			ln -f $(APTDIR)/cache/archives/$$package\_* \
				$(UDEBDIR)/$$package.udeb; \
		fi; \
		if [ -e $(LOCALUDEBDIR)/$$package\_* ]; then \
			ln -f $(LOCALUDEBDIR)/$$package\_* \
				$(UDEBDIR)/$$package.udeb; \
		fi; \
	done

# Build the installer tree.
tree: get_udebs
	dh_testroot

	# This build cannot be restarted, because dpkg gets confused.
	rm -rf $(DEST)
	# Set up the basic files [u]dpkg needs.
	mkdir -p $(DPKGDIR)/info
	touch $(DPKGDIR)/status
	# Only dpkg needs this stuff, so it can be removed later.
	mkdir -p $(DPKGDIR)/updates/
	touch $(DPKGDIR)/available
	# Unpack the udebs with dpkg. This command must run as root or fakeroot.
	dpkg --root=$(DEST) --unpack $(UDEBDIR)/*.udeb
	# Clean up after dpkg.
	rm -rf $(DPKGDIR)/updates
	rm -f $(DPKGDIR)/available $(DPKGDIR)/*-old $(DPKGDIR)/lock
	# TODO: configure some of the packages?

# Library reduction.
lib_reduce:
	mkdir -p $(DEST)/lib
	mklibs.sh -v -d $(DEST)/lib `find $(DEST) -type f -perm +0111 -o -name '*.so'`
	# Now we have reduced libraries installed .. but they are
	# not listed in the status file. This nasty thing puts them in,
	# and alters their names to end in -reduced to indicate that
	# they have been modified.
	for package in $$(dpkg -S `find debian-installer/lib -type f | \
			sed s:debian-installer::` | cut -d : -f 1 | \
			sort | uniq); do \
		dpkg -s $$package >> $(DPKGDIR)/status; \
		sed "s/$$package/$$package-reduced/g" \
			< $(DPKGDIR)/status > $(DPKGDIR)/status-new; \
		mv -f $(DPKGDIR)/status-new $(DPKGDIR)/status; \
	done

# Reduce a status file to contain only the elements we care about.
status_reduce:
	egrep -i '^((Status|Provides|Depends|Package|Description|installer-menu-item):|$$)' \
		$(DPKGDIR)/status > $(DPKGDIR)/status.new
	mv -f $(DPKGDIR)/status.new $(DPKGDIR)/status

stats:
	@echo
	@echo System stats
	@echo ------------
	@echo Installed udebs: $(UDEBS)
	@echo Total system size: $(shell du -h -s $(DEST) | cut -f 1)
	@echo Compresses to: $(shell expr $(shell tar cz $(DEST) | wc -c) / 1024)k
# Add your interesting stats here.

# Upload a daily build to klecker. If you're not Joey Hess, you probably
# don't want to use this grungy code, at least not without overrideing
# this:
UPLOAD_DIR=klecker.debian.org:~/public_html/debian-installer/daily/
daily_build:
	fakeroot $(MAKE) PATH=$$PATH:. build > log 2>&1
	$(MAKE) image
	scp -q -B log $(UPLOAD_DIR)
	scp -q -B ../debian-installer.tar.gz \
		$(UPLOAD_DIR)/debian-installer-$(shell date +%Y%m%d).tar.gz
	rm -f log
