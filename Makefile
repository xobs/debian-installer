#!/usr/bin/make -f
#
# Debian Installer system makefile.
# Copyright 2001 by Joey Hess <joeyh@debian.org>.
# Licensed under the terms of the GPL.
#
# This makefile builds a debian-installer system and bootable images from 
# a collection of udebs which it downloads from a Debian archive. See
# README for details.

architecture    := $(shell dpkg-architecture -qDEB_HOST_ARCH)

# The version of the kernel to use.

ifeq "$(architecture)" "i386"
KVERS=2.4.18
FLAVOUR=386
KERNELNAME=vmlinuz
endif
ifeq "$(architecture)" "powerpc"
KVERS=2.4.19
FLAVOUR=powerpc
KERNELNAME=vmlinux
endif

# The type of system to build. Determines what udebs are unpacked into
# the system. See the .list files for various types. You may want to
# override this on the command line.
TYPE=net

# The library reducer to use. Can be mklibs.sh or mklibs.py.
MKLIBS=mklibs

# List here any libraries that need to be put on the system. Generally
# this is not needed except for libnss_* libraries, which will not be
# automatically pulled in by the library reduction code. Wildcards are
# allowed.
# TODO: this really needs to be determined on a per TYPE basis.
#       libnss_nns is needed for many, but not all, install scenarios
EXTRALIBS=/lib/libnss_dns* /lib/libresolv*

# List here any extra udebs that are not in the list file but that
# should still be included on the system.
EXTRAS=""

# This variable can be used to copy in additional files from the system
# that is doing the build. Useful if you need to include strace, or gdb,
# or just something extra on a floppy.
#EXTRAFILES=/usr/bin/strace

# set DEBUG to y if you want to get the source for and compile 
# debug versions of the needed udebs
DEBUG=n

# All output files will go here.
DEST=dest

# Filename of initrd to create.
INITRD=$(DEST)/$(TYPE)-initrd.gz

# How big a floppy image should I make? (in kilobytes)
FLOPPY_SIZE=1440

# The floppy image to create.
FLOPPY_IMAGE=$(DEST)/$(TYPE)-$(FLOPPY_SIZE).img

# What device to write floppies on
FLOPPYDEV=/dev/fd0

# May be needed in rare cases.
#SYSLINUX_OPTS=-s

# Directory apt uses for stuff.
APTDIR=apt

# Directory udebs are placed in.
UDEBDIR=udebs

# Local directory that is searched for udebs, to avoid downloading.
# (Or for udebs that are not yet available for download.)
LOCALUDEBDIR=localudebs

# Directory where debug versions of udebs will be built.
DEBUGUDEBDIR=debugudebs

# The beta version of upx can be used to make the kernel a lot smaller
# it shaved 75k off our kernel. That allows us to put a lot more on
# a single floppy. binaries are at:
# http://wildsau.idv.uni-linz.ac.at/mfx/download/upx/unstable/upx-1.11-linux.tar.gz
# or source at:
# http://sourceforge.net/projects/upx/
#UPX=~davidw/bin/upx
UPX=

# Figure out which sources.list to use. The .local one is preferred,
# so you can set up a locally preferred one (and not accidentially cvs
# commit it).
ifeq ($(wildcard sources.list.local),sources.list.local)
SOURCES_LIST=sources.list.local
else
SOURCES_LIST=sources.list
endif

# Add to PATH so dpkg will always work, and so local programs will
# be found.
PATH:=$(PATH):/usr/sbin:/sbin:.

# All these options make apt read the right sources list, and
# use APTDIR for everything so it need not run as root.
CWD:=$(shell pwd)/
APT_GET=apt-get --assume-yes \
	-o Dir::Etc::sourcelist=$(CWD)$(SOURCES_LIST) \
	-o Dir::State=$(CWD)$(APTDIR)/state \
	-o Debug::NoLocking=true \
	-o Dir::Cache=$(CWD)$(APTDIR)/cache

# Get the list of udebs to install. Comments are allowed in the lists.
UDEBS=$(shell grep --no-filename -v ^\# pkg-lists/base pkg-lists/$(TYPE)/common `if [ -f pkg-lists/$(TYPE)/$(architecture) ]; then echo pkg-lists/$(TYPE)/$(architecture); fi` | sed 's/$${kernel:Version}/$(KVERS)/g' | sed 's/$${kernel:Flavour}/$(FLAVOUR)/g') $(EXTRAS)

DPKGDIR=$(TREE)/var/lib/dpkg
TEMP=./tmp
TMP_MNT=`pwd`/mnt/

# Build tree location.
TREE=$(TEMP)/tree

# This is the kernel image that we will boot from.
KERNEL=$(TEMP)/$(KERNELNAME)

build: demo_clean tree stats

demo: tree
	sudo chroot $(TREE) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(TREE) bin/sh -c "export DEBCONF_FRONTEND=default_fe DEBCONF_DEBUG=5; /usr/bin/debconf-loadtemplate debian /var/lib/dpkg/info/*.templates; /usr/share/debconf/frontend /usr/bin/main-menu"
	$(MAKE) demo_clean

shell: tree
	mkdir -p $(TREE)/proc 
	sudo chroot $(TREE) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(TREE) bin/sh
	$(MAKE) demo_clean

demo_clean:
	-if [ -e $(TREE)/proc/self ]; then \
		sudo chroot $(TREE) bin/sh -c "if mount | grep ^proc ; then bin/umount /proc ; fi" &> /dev/null; \
	fi

clean: demo_clean
	dh_clean
	rm -f *-stamp
	rm -rf $(TREE) $(APTDIR) $(UDEBDIR) $(TEMP) $(DEST)

# Get all required udebs and put in UDEBDIR.
get_udebs: get_udebs-stamp
get_udebs-stamp:
	mkdir -p $(APTDIR)/state/lists/partial
	mkdir -p $(APTDIR)/cache/archives/partial
	$(APT_GET) update
	$(APT_GET) autoclean
	# If there are local udebs, remove them from the list of things to
	# get. Then get all the udebs that are left to get.
	needed="$(UDEBS)"; \
	for file in `find $(LOCALUDEBDIR) -name "*_*" -printf "%f\n" 2>/dev/null`; do \
		package=`echo $$file | cut -d _ -f 1`; \
		needed=`echo " $$needed " | sed "s/ $$package */ /"`; \
	done; \
	if [ $(DEBUG) = y ] ; then \
		mkdir -p $(DEBUGUDEBDIR); \
		cd $(DEBUGUDEBDIR); \
		export DEB_BUILD_OPTIONS="debug"; \
		$(APT_GET) source --build --yes $$needed; \
		cd ..; \
	else \
		echo Need to download : $$needed; \
		if [ -n "$$needed" ]; then \
		$(APT_GET) -dy install $$needed; \
		fi; \
	fi; \

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
		if [ -e $(DEBUGUDEBDIR)/$$package\_*.udeb ]; then \
			ln -f $(DEBUGUDEBDIR)/$$package\_*.udeb \
				$(UDEBDIR)/$$package.udeb; \
		fi; \
	done

	touch get_udebs-stamp


# Build the installer tree.
tree: get_udebs tree-stamp
tree-stamp:
	dh_testroot

	dpkg-checkbuilddeps

	# This build cannot be restarted, because dpkg gets confused.
	rm -rf $(TREE)
	# Set up the basic files [u]dpkg needs.
	mkdir -p $(DPKGDIR)/info
	touch $(DPKGDIR)/status
	# Create a tmp tree
	mkdir -p $(TREE)/tmp
	# Only dpkg needs this stuff, so it can be removed later.
	mkdir -p $(DPKGDIR)/updates/
	touch $(DPKGDIR)/available
	# Unpack the udebs with dpkg. This command must run as root or fakeroot.
	dpkg --force-overwrite --root=$(TREE) --unpack $(UDEBDIR)/*.udeb
	# Clean up after dpkg.
	rm -rf $(DPKGDIR)/updates
	rm -f $(DPKGDIR)/available $(DPKGDIR)/*-old $(DPKGDIR)/lock
	# Set up modules.dep
	mkdir -p $(TREE)/lib/modules/$(KVERS)-$(FLAVOUR)/
	depmod -q -a -b $(TREE)/ $(KVERS)-$(FLAVOUR)
	# These files depmod makes are used by hotplug, and we shouldn't
	# need them, yet anyway.
	find $(TREE)/lib/modules/$(KVERS)-$(FLAVOUR)/ -name 'modules*' \
		-not -name modules.dep | xargs rm -f
	# Install /dev devices (but not too much)
	mkdir -p $(TREE)/dev
	cd $(TREE)/dev && /sbin/MAKEDEV std console
	rm $(TREE)/dev/vcs*
	rm $(TREE)/dev/tty[1-9][0-9]
	if [ ! -c $(TREE)/dev/console ]; then \
	    echo "WARNING: $(TREE)/dev/console isn't a character device as it should."; \
	    echo "This does probably mean that you should start again with root rights."; \
	fi

	# Move the kernel image out of the way, into a temp directory
	# for use later. We don't need it bloating our image!
	mv -f $(TREE)/boot/$(KERNELNAME) $(KERNEL)
	-rmdir $(TREE)/boot/

	# Copy terminfo files for slang frontend
	# TODO: terminfo.udeb?
	for file in /etc/terminfo/a/ansi /etc/terminfo/l/linux \
		    /etc/terminfo/v/vt102; do \
		mkdir -p $(TREE)/`dirname $$file`; \
		cp -a $$file $(TREE)/$$file; \
	done

ifdef EXTRAFILES
	# Copy in any extra files
	for file in $(EXTRAFILES); do \
		mkdir -p $(TREE)/`dirname $$file`; \
		cp -a $$file $(TREE)/$$file; \
	done
endif

	# Copy in any extra libs.
ifdef EXTRALIBS
	cp -a $(EXTRALIBS) $(TREE)/lib/
endif

	# Library reduction.
	mkdir -p $(TREE)/lib
	$(MKLIBS) -v -d $(TREE)/lib `find $(TREE) -type f -perm +0111 -o -name '*.so'`

	# Add missing symlinks for libraries
	# (Needed for mklibs.py)
	/sbin/ldconfig -n $(TREE)/lib $(TREE)/usr/lib

	# Remove any libraries that are present in both usr/lib and lib,
	# from lib. These were unnecessarily copied in by mklibs, and
	# we want to use the ones in usr/lib instead since they came 
	# from udebs. Only libdebconf has this problem so far.
	for lib in `find $(TREE)/usr/lib/lib* -type f -printf "%f\n" | cut -d . -f 1 | sort | uniq`; do \
		rm -f $(TREE)/lib/$$lib.*; \
	done

	# Now we have reduced libraries installed .. but they are
	# not listed in the status file. This nasty thing puts them in,
	# and alters their names to end in -reduced to indicate that
	# they have been modified.
	for package in $$(dpkg -S `find $(TREE)/lib -type f -not -name '*.o'| \
			sed s:$(TREE)::` | cut -d : -f 1 | \
			sort | uniq); do \
		dpkg -s $$package | sed "s/$$package/$$package-reduced/g" \
			>> $(DPKGDIR)/status; \
	done

	# Reduce status file to contain only the elements we care about.
	egrep -i '^((Status|Provides|Depends|Package|Description|installer-menu-item|Description-..):|$$)' \
		$(DPKGDIR)/status > $(DPKGDIR)/status.udeb
	rm -f $(DPKGDIR)/status
	ln -sf status.udeb $(DPKGDIR)/status

	# Strip all kernel modules, just in case they haven't already been
	for module in `find $(TREE)/lib/modules/ -name '*.o'`; do \
	    strip -R .comment -R .note -g -x $$module; \
	done

	# Remove some unnecessary dpkg files.
	for file in `find $(TREE)/var/lib/dpkg/info -name '*.md5sums' -o \
	    -name '*.postrm' -o -name '*.prerm' -o -name '*.preinst' -o \
	    -name '*.list'`; do \
	    rm $$file; \
	done

	touch tree-stamp

tarball: tree
	tar czf $(DEST)/$(TYPE)-debian-installer.tar.gz $(TREE)

# Make sure that the temporary mountpoint exists and is not occupied.
tmp_mount:
	dh_testroot
	if mount | grep -q $(TMP_MNT) && ! umount $(TMP_MNT) ; then \
		echo "Error unmounting $(TMP_MNT)" 2>&1 ; \
		exit 1; \
	fi
	mkdir -p $(TMP_MNT)

# Create a compressed image of the root filesystem by way of genext2fs.

initrd: Makefile tmp_mount tree $(INITRD)
$(INITRD): TMP_FILE=$(TEMP)/image.tmp
$(INITRD):
	dh_testroot
	rm -f $(TMP_FILE)
	install -d $(TEMP)
	install -d $(DEST)
	genext2fs -d $(TREE) -b `expr $$(du -s $(TREE) | cut -f 1) + $$(expr $$(find $(TREE) | wc -l) \* 2)` $(TMP_FILE)
	dd if=$(TMP_FILE) bs=1k | gzip -v9 > $(INITRD)

# Create a bootable floppy image. i386 specific. FIXME
# 1. make a dos filesystem image
# 2. copy over kernel, initrd
# 3. install syslinux
floppy_image: Makefile initrd tmp_mount $(FLOPPY_IMAGE)
$(FLOPPY_IMAGE):
	dh_testroot
	install -d $(DEST)

	dd if=/dev/zero of=$(FLOPPY_IMAGE) bs=1k count=$(FLOPPY_SIZE)
	mkfs.msdos -i deb00001 -n 'Debian Installer' -C $(FLOPPY_IMAGE)	$(FLOPPY_SIZE)
	mount -t vfat -o loop $(FLOPPY_IMAGE) $(TMP_MNT)

	cp $(KERNEL) $(TMP_MNT)/linux
	cp $(INITRD) $(TMP_MNT)/initrd.gz

	cp syslinux.cfg $(TMP_MNT)/
	todos $(TMP_MNT)/syslinux.cfg
	umount $(TMP_MNT)
	syslinux $(SYSLINUX_OPTS) $(FLOPPY_IMAGE)

# Write image to floppy
boot_floppy: floppy_image
	install -d $(DEST)
	dd if=$(FLOPPY_IMAGE) of=$(FLOPPYDEV)

# If you're paranoid (or things are mysteriously breaking..),
# you can check the floppy to make sure it wrote properly.
# This target will fail if the floppy doesn't match the floppy image.
boot_floppy_check: floppy_image
	cmp $(FLOPPYDEV) $(FLOPPY_IMAGE)

COMPRESSED_SZ=$(shell expr $(shell tar cz $(TREE) | wc -c) / 1024)
KERNEL_SZ=$(shell expr $(shell du -b $(KERNEL) | cut -f 1) / 1024)
stats: tree
	@echo
	@echo "System stats"
	@echo "------------"
	@echo "Installed udebs: $(UDEBS)"
	@echo -n "Total system size: $(shell du -h -s $(TREE) | cut -f 1)"
	@echo -n " ($(shell du -h --exclude=modules -s $(TREE)/lib | cut -f 1) libs, "
	@echo "$(shell du -h -s $(TREE)/lib/modules | cut -f 1) kernel modules)"
	@echo "Initrd size: $(COMPRESSED_SZ)k"
	@echo "Kernel size: $(KERNEL_SZ)k"
	@echo "Free space: $(shell expr $(FLOPPY_SIZE) - $(KERNEL_SZ) - $(COMPRESSED_SZ))k"
# Add your interesting stats here.


# Upload a daily build to peope.debian.org. If you're not Joey Hess, you probably
# don't want to use this grungy code, at least not without overrideing
# this:
UPLOAD_DIR=people.debian.org:~/public_html/debian-installer/daily/
daily_build:
	-cvs update
	dpkg-checkbuilddeps
	$(MAKE) clean
	install -d $(DEST)
	fakeroot $(MAKE) tarball > $(DEST)/log 2>&1
	$(MAKE) stats > $(DEST)/$(TYPE).info
	echo "Tree comparison" >> $(DEST)/$(TYPE).info
	echo "" >> $(DEST)/$(TYPE).info
	if [ -d $(TYPE)-oldtree ]; then \
		./treecompare $(TYPE)-oldtree $(TREE) >> $(DEST)/$(TYPE).info; \
	fi
	scp -q -B $(DEST)/log $(UPLOAD_DIR)
	scp -q -B $(DEST)/$(TYPE)-debian-installer.tar.gz \
		$(UPLOAD_DIR)/$(TYPE)-debian-installer-$(shell date +%Y%m%d).tar.gz
	scp -q -B $(DEST)/$(TYPE).info \
		$(UPLOAD_DIR)/$(TYPE).info-$(shell date +%Y%m%d)
	rm -rf $(TYPE)-oldtree
	-mv $(TREE) $(TYPE)-oldtree && rm -f tree-stamp
	mail $(shell whoami) -s "today's build info" < $(DEST)/$(TYPE).info

.PHONY: tree
