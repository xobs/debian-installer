#!/usr/bin/make -f
#
# Debian Installer system makefile.
# Copyright 2001, 2002 by Joey Hess <joeyh@debian.org>.
# Licensed under the terms of the GPL.
#
# This makefile builds a debian-installer system and bootable images from 
# a collection of udebs which it downloads from a Debian archive. See
# README for details.

architecture    := $(shell dpkg-architecture -qDEB_HOST_ARCH)

# The version of the kernel to use.

ifeq "$(architecture)" "alpha"
KERNELVERSION=2.4.20-generic
KERNELNAME=vmlinuz
endif
ifeq "$(architecture)" "hppa"
KERNELIMAGEVERSION=2.4.19-32
KERNELVERSION=${KERNELIMAGEVERSION}-udeb
KERNELNAME=vmlinux-${KERNELVERSION}
KERNELIMAGEVERSION_SECOND=2.4.19-64
KERNELVERSION_SECOND=${KERNELIMAGEVERSION_SECOND}-udeb
KERNELNAME_SECOND=vmlinux-${KERNELVERSION_SECOND}
endif
ifeq "$(architecture)" "sparc"
KERNELIMAGEVERSION=2.2.20-sun4cdm
KERNELVERSION=${KERNELIMAGEVERSION}-udeb
KERNELNAME=vmlinuz-${KERNELVERSION}
KERNELIMAGEVERSION_SECOND=2.4.20-sun4u
KERNELVERSION_SECOND=${KERNELIMAGEVERSION_SECOND}-udeb
KERNELNAME_SECOND=vmlinuz-${KERNELVERSION_SECOND}
endif
ifeq "$(architecture)" "i386"
KERNELVERSION=2.4.20-386
KERNELNAME=vmlinuz
endif
ifeq "$(architecture)" "ia64"
KERNELVERSION=2.4.19-ia64
KERNELNAME=vmlinuz
endif
ifeq "$(architecture)" "powerpc"
KERNELVERSION=2.4.19-powerpc
KERNELNAME=vmlinux
endif
ifeq "$(architecture)" "s390"
KERNELIMAGEVERSION=2.4.19-s390
KERNELVERSION=2.4.19
KERNELNAME=vmlinux
KERNELNAME_SECOND=vmlinux-tape
endif
ifeq "$(architecture)" "m68k"
# change the following line for other subarchs
KERNELIMAGEVERSION=2.2.20-mac
KERNELVERSION=2.2.20
KERNELNAME=vmlinuz
USERDEVFS=t
endif

ifndef KERNELIMAGEVERSION
KERNELIMAGEVERSION=${KERNELVERSION}
endif
ifndef KERNELIMAGEVERSION_SECOND
KERNELIMAGEVERSION_SECOND=${KERNELVERSION_SECOND}
endif

# The type of system to build. Determines what udebs are unpacked into
# the system. See the .list files for various types. You may want to
# override this on the command line.
#TYPE=net
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
EXTRAS=

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

# Filesystem type for the initrd, valid values are romfs and ext2.
# NOTE: Your kernel must support this filesystem, not just a module. 
# INITRD_FS=ext2
INITRD_FS=ext2

# How big a floppy image should I make? (in kilobytes)
ifeq (cdrom,$(TYPE))
FLOPPY_SIZE=2880
else
FLOPPY_SIZE=1440
endif

# The floppy image to create.
FLOPPY_IMAGE=$(DEST)/$(TYPE)-$(FLOPPY_SIZE).img

# Creating floppy images requires mounting the image to copy files to it.
# This generally needs root permissions. To let a user mount the floppy
# image, add something like this to /etc/fstab:
#   /dir/debian-installer/build/dest/tmp-mnt.img /dir/debian-installer/build/mnt vfat noauto,user,loop 0 0
# Changing "/dir" to the full path to wherever debian-installer will be
# built. Then if you uncomment this next line, the Makefile will use
# commands that work with the above fstab line. Be careful: This lets any
# user mount the image file you list in fstab, and the user who can create
# that file could perhaps provide a maliciously constructed file that might
# crash the kernel or worse.. Note that this line points to the temporary
# image file to create, and MUST be an absolute path. Finally, when calling
# the floppy_image target, you must *not* use fakeroot, or syslinux will
# fail.
#USER_MOUNT_HACK=$(shell pwd)/$(DEST)/tmp-mnt.img

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
UDEBS=$(shell grep --no-filename -v ^\# pkg-lists/base pkg-lists/$(TYPE)/common `if [ -f pkg-lists/$(TYPE)/$(architecture) ]; then echo pkg-lists/$(TYPE)/$(architecture); fi` | sed -e 's/$${kernel:Version}/$(KERNELIMAGEVERSION)/g' -e 's/$${kernel_second:Version}/$(KERNELIMAGEVERSION_SECOND)/g') $(EXTRAS)

# Scratch directory.
BASE_TMP=./tmp/
# Per-type scratch directory.
TEMP=$(BASE_TMP)$(TYPE)

# Build tree location.
TREE=$(TEMP)/tree

DPKGDIR=$(TREE)/var/lib/dpkg
TMP_MNT=`pwd`/mnt/

# This is the kernel image that we will boot from.
KERNEL=$(TEMP)/$(KERNELNAME)
KERNEL_SECOND=$(TEMP)/$(KERNELNAME_SECOND)

build: demo_clean tree stats

demo: tree
	-@sudo chroot $(TREE) bin/sh -c "bin/umount /dev; bin/mount -t devfs dev /dev" &> /dev/null
	-@sudo chroot $(TREE) bin/sh -c "bin/umount /proc; bin/mount -t proc proc /proc" &> /dev/null
	-@[ -f questions.dat ] && cp -f questions.dat $(TREE)/var/lib/cdebconf/
	-@sudo chroot $(TREE) bin/sh -c "export DEBCONF_DEBUG=5; /usr/bin/debconf-loadtemplate debian /var/lib/dpkg/info/*.templates; exec /usr/share/debconf/frontend /usr/bin/main-menu"
	$(MAKE) demo_clean

shell: tree
	-@sudo chroot $(TREE) bin/sh -c "bin/umount /dev; bin/mount -t devfs dev /dev" &> /dev/null
	-@sudo chroot $(TREE) bin/sh -c "bin/umount /proc; bin/mount -t proc proc /proc" &> /dev/null
	-@sudo chroot $(TREE) bin/sh
	$(MAKE) demo_clean

uml: initrd
	-linux initrd=$(INITRD) root=/dev/rd/0 ramdisk_size=8192 con=fd:0,fd:1 devfs=mount

demo_clean:
	-@sudo chroot $(TREE) bin/sh -c "bin/umount /dev ; bin/umount /proc" &> /dev/null

clean: demo_clean tmp_mount
	if [ "$(USER_MOUNT_HACK)" ] ; then \
	    if mount | grep -q "$(USER_MOUNT_HACK)"; then \
	        umount "$(USER_MOUNT_HACK)";\
	    fi ; \
	fi
	rm -rf $(TREE) 2>/dev/null || sudo rm -rf $(TREE)
	dh_clean
	rm -f *-stamp
	rm -rf $(UDEBDIR) $(TMP_MNT)
	rm -rf $(DEST)/$(TYPE)-* || sudo rm -rf $(DEST)/$(TYPE)-*

reallyclean: clean
	rm -rf $(APTDIR) $(DEST) $(BASE_TMP)

# Get all required udebs and put in UDEBDIR.
get_udebs: $(TYPE)-get_udebs-stamp
$(TYPE)-get_udebs-stamp:
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

	# Now the udebs are in APTDIR/cache/archives/ and maybe LOCALUDEBDIR
	# or DEBUGUDEBDIR, but there may be other udebs there too besides those
	# we asked for.  So link those we asked for to UDEBDIR, renaming them
	# to more useful names. Watch out for duplicates and missing files
	# while doing that.
	rm -rf $(UDEBDIR)
	mkdir -p $(UDEBDIR)
	lnpkg() { \
		local pkg=$$1; local dir=$$2; \
		local L1="`echo $$dir/$$pkg\_*`"; \
		local L2="`echo $$L1 | sed -e 's, ,,g'`"; \
		if [ "$$L1" != "$$L2" ]; then \
			echo "Duplicate package $$pkg in $$dir/"; \
			exit 1; \
		fi; \
		if [ -e $$L1 ]; then \
			ln -f $$dir/$$pkg\_* $(UDEBDIR)/$$pkg.udeb; \
		fi; \
	}; \
	for package in $(UDEBS); do \
		lnpkg $$package $(APTDIR)/cache/archives; \
		lnpkg $$package $(LOCALUDEBDIR); \
		lnpkg $$package $(DEBUGUDEBDIR); \
		if ! [ -e $(UDEBDIR)/$$package.udeb ]; then \
			echo "Needed $$package not found (looked in $(APTDIR)/cache/archives/, $(LOCALUDEBDIR)/, $(DEBUGUDEBDIR)/)"; \
			exit 1; \
		fi; \
	done

	touch $(TYPE)-get_udebs-stamp


# Build the installer tree.
tree: get_udebs $(TYPE)-tree-stamp
$(TYPE)-tree-stamp:
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

	# Unpack the udebs with dpkg. This command must run as root
	# or fakeroot.
	echo -n > diskusage-$(TYPE).txt
	oldsize=0; oldcount=0; for udeb in $(UDEBDIR)/*.udeb ; do \
		pkg=`basename $$udeb` ; \
		dpkg --force-overwrite --root=$(TREE) --unpack $$udeb ; \
		newsize=`du -s $(TREE) | awk '{print $$1}'` ; \
		newcount=`find $(TREE) -type f | wc -l | awk '{print $$1}'` ; \
		usedsize=`echo $$newsize - $$oldsize | bc`; \
		usedcount=`echo $$newcount - $$oldcount | bc`; \
		echo $$usedsize KiB and $$usedcount files used by pkg $$pkg >>diskusage-$(TYPE).txt;\
		oldsize=$$newsize ; \
		oldcount=$$newcount ; \
	done
	sort -n < diskusage-$(TYPE).txt > diskusage-$(TYPE).txt.new && \
	mv diskusage-$(TYPE).txt.new diskusage-$(TYPE).txt

	# Clean up after dpkg.
	rm -rf $(DPKGDIR)/updates
	rm -f $(DPKGDIR)/available $(DPKGDIR)/*-old $(DPKGDIR)/lock
ifdef USERDEVFS
	# Create initial /dev entries -- only those that are absolutely
	# required to boot sensibly, though.
	mknod $(TREE)/dev/console c 5 1
	mknod $(TREE)/dev/tty0 c 4 0
	mknod $(TREE)/dev/tty1 c 4 1
	mknod $(TREE)/dev/tty2 c 4 2
	mknod $(TREE)/dev/tty3 c 4 3
	mknod $(TREE)/dev/tty4 c 4 4
	mknod $(TREE)/dev/tty5 c 4 5
endif
	# Set up modules.dep, ensure there is at least one standard dir (kernel
	# in this case), so depmod will use its prune list for archs with no
	# modules.
	mkdir -p $(TREE)/lib/modules/$(KERNELVERSION)/kernel
	depmod -q -a -b $(TREE)/ $(KERNELVERSION)
ifdef KERNELVERSION_SECOND
	mkdir -p $(TREE)/lib/modules/$(KERNELVERSION_SECOND)/kernel
	depmod -q -a -b $(TREE)/ $(KERNELVERSION_SECOND)
endif
	# These files depmod makes are used by hotplug, and we shouldn't
	# need them, yet anyway.
	find $(TREE)/lib/modules/ -name 'modules*' \
		-not -name modules.dep | xargs rm -f
	# Create a dev tree
	mkdir -p $(TREE)/dev

	# Move the kernel image out of the way, into a temp directory
	# for use later. We don't need it bloating our image!
	mv -f $(TREE)/boot/$(KERNELNAME) $(KERNEL)
ifdef KERNELNAME_SECOND
	mv -f $(TREE)/boot/$(KERNELNAME_SECOND) $(KERNEL_SECOND)
endif
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
	egrep -i '^((Status|Provides|Depends|Package|Version|Description|installer-menu-item|Description-..):|$$)' \
		$(DPKGDIR)/status > $(DPKGDIR)/status.udeb
	rm -f $(DPKGDIR)/status
	ln -sf status.udeb $(DPKGDIR)/status

	# Strip all kernel modules, just in case they haven't already been
	for module in `find $(TREE)/lib/modules/ -name '*.o'`; do \
	    strip -R .comment -R .note -g $$module; \
	done

	# Remove some unnecessary dpkg files.
	for file in `find $(TREE)/var/lib/dpkg/info -name '*.md5sums' -o \
	    -name '*.postrm' -o -name '*.prerm' -o -name '*.preinst' -o \
	    -name '*.list'`; do \
	    rm $$file; \
	done

	touch $(TYPE)-tree-stamp

# Collect the used UTF-8 strings, to know which glyphs to include in
# the font.  Using strigs is not the best way, but no better suggestion
# has been made yet.
all.utf: $(TYPE)-tree-stamp
	cp graphic.utf all.utf
	cat $(TREE)/var/lib/dpkg/info/*.templates >> all.utf
	find $(TREE) -type f | xargs strings >> all.utf

unifont-reduced.bdf: all.utf
	# Need to use an UTF-8 based locale to get reduce-font working.
	# Any will do.  en_IN seem fine and was used by boot-floppies
	# reduce-font is part of package libbogl-dev
	# unifont.bdf is part of package bf-utf-source
	LC_ALL=en_IN.UTF-8 reduce-font /usr/src/unifont.bdf < all.utf > $@

$(TREE)/unifont-reduced.bgf: unifont-reduced.bdf
	# bdftobogl is part of package libbogl-dev
	bdftobogl -b unifont-reduced.bdf > $@

tarball: tree
	tar czf $(DEST)/$(TYPE)-debian-installer.tar.gz $(TREE)

# Make sure that the temporary mountpoint exists and is not occupied.
tmp_mount:
	if mount | grep -q $(TMP_MNT) && ! umount $(TMP_MNT) ; then \
		echo "Error unmounting $(TMP_MNT)" 2>&1 ; \
		exit 1; \
	fi

	mkdir -p $(TMP_MNT)

# Create a compressed image of the root filesystem by way of genext2fs.
initrd: Makefile tmp_mount tree $(INITRD)
$(INITRD): TMP_FILE=$(TEMP)/image.tmp
$(INITRD):
	rm -f $(TMP_FILE)
	install -d $(TEMP)
	install -d $(DEST)
	if [ $(INITRD_FS) = ext2 ]; then \
		genext2fs -d $(TREE) -b `expr $$(du -s $(TREE) | cut -f 1) + $$(expr $$(find $(TREE) | wc -l) \* 2)` $(TMP_FILE); \
	elif [ $(INITRD_FS) = romfs ]; then \
		genromfs -d $(TREE) -f $(TMP_FILE); \
	else \
		echo "Unsupported filesystem type"; \
		exit 1; \
	fi;
	gzip -vc9 $(TMP_FILE) > $(INITRD)

# hppa boots a lifimage, which can contain an initrd and two kernels (one 32 and one 64 bit)
lifimage: Makefile initrd $(DEST)/$(TYPE)-lifimage $(KERNEL) $(KERNEL_SECOND)
$(DEST)/$(TYPE)-lifimage:
	palo -f /dev/null -k $(KERNEL) -k $(KERNEL_SECOND) -r $(INITRD) -s $(DEST)/$(TYPE)-lifimage \
		-c "0/linux HOME=/ ramdisk_size=8192 initrd=0/ramdisk rw"

# Create a bootable floppy image. i386 specific. FIXME
# 1. make a dos filesystem image
# 2. copy over kernel, initrd
# 3. install syslinux
floppy_image: Makefile initrd tmp_mount $(FLOPPY_IMAGE)
$(FLOPPY_IMAGE):
	install -d $(DEST)

	dd if=/dev/zero of=$(FLOPPY_IMAGE).new bs=1k count=$(FLOPPY_SIZE)
	mkfs.msdos -i deb00001 -n 'Debian Installer' -C $(FLOPPY_IMAGE).new $(FLOPPY_SIZE)

ifdef USER_MOUNT_HACK
	ln -sf `pwd`/$(FLOPPY_IMAGE).new $(USER_MOUNT_HACK)
	mount $(TMP_MNT)
else
	mount -t vfat -o loop $(FLOPPY_IMAGE).new $(TMP_MNT)
endif

	# syslinux is used to make the floppy bootable.
	if cp $(KERNEL) $(TMP_MNT)/linux \
	   && cp $(INITRD) $(TMP_MNT)/initrd.gz \
	   && cp syslinux.cfg $(TMP_MNT)/ \
	   && todos $(TMP_MNT)/syslinux.cfg ; \
	then \
		umount $(TMP_MNT) ; \
		true ; \
	else \
		umount $(TMP_MNT) ; \
		false ; \
	fi

ifdef USER_MOUNT_HACK
	syslinux $(SYSLINUX_OPTS) $(USER_MOUNT_HACK)
	rm -f $(USER_MOUNT_HACK)
else
	syslinux $(SYSLINUX_OPTS) $(FLOPPY_IMAGE).new
endif

	# Finalize the image.
	mv $(FLOPPY_IMAGE).new $(FLOPPY_IMAGE)

# Copy files somewhere the CD build scripts can find them
cd_content: floppy_image
	cp $(KERNEL) $(DEST)/$(TYPE)-linux
	cp syslinux.cfg $(DEST)/$(TYPE)-syslinux.cfg

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
	@echo "Disk usage per package:"
	@sed 's/^/  /' < diskusage-$(TYPE).txt
# Add your interesting stats here.


# Upload a daily build to peope.debian.org. If you're not Joey Hess,
# you probably don't want to use this grungy code, at least not without
# overriding this:
UPLOAD_DIR=people.debian.org:~/public_html/debian-installer/daily/
ALL_TYPES=$(shell find pkg-lists -type d -maxdepth 1 -mindepth 1 -not -name CVS -printf '%f\n')
daily_build:
	-cvs update
	dpkg-checkbuilddeps
	$(MAKE) clean

	install -d $(DEST)
	rm -f $(DEST)/info
	touch $(DEST)/info
	set -e; \
	for type in $(ALL_TYPES); do \
		$(MAKE) sub_daily_build TYPE=$$type USER_MOUNT_HACK=$(shell pwd)/$(DEST)/tmp-mnt.img; \
	done
	scp -q -B $(KERNEL) $(UPLOAD_DIR)/images/
	mail $(shell whoami) -s "today's build info" < $(DEST)/info

sub_daily_build:
	fakeroot $(MAKE) tarball > $(DEST)/$(TYPE).log 2>&1
	$(MAKE) floppy_image >> $(DEST)/$(TYPE).log 2>&1
	$(MAKE) stats | grep -v ^make > $(DEST)/$(TYPE).info
	echo "Tree comparison" >> $(DEST)/$(TYPE).info
	echo "" >> $(DEST)/$(TYPE).info
	if [ -d $(TYPE)-oldtree ]; then \
		./treecompare $(TYPE)-oldtree $(TREE) >> $(DEST)/$(TYPE).info; \
	fi
	scp -q -B $(DEST)/$(TYPE).log $(UPLOAD_DIR)
	scp -q -B $(DEST)/$(TYPE)-debian-installer.tar.gz \
		$(UPLOAD_DIR)/$(TYPE)-debian-installer-$(shell date +%Y%m%d).tar.gz
	scp -q -B $(FLOPPY_IMAGE) $(INITRD) $(UPLOAD_DIR)/images/
	scp -q -B $(DEST)/$(TYPE).info \
		$(UPLOAD_DIR)/$(TYPE).info-$(shell date +%Y%m%d)
	echo "Type: $(TYPE)" >> $(DEST)/info
	cat $(DEST)/$(TYPE).info >> $(DEST)/info
	rm -rf $(TYPE)-oldtree
	-mv $(TREE) $(TYPE)-oldtree && rm -f $(TYPE)-tree-stamp

.PHONY: tree
