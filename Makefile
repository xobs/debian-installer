#!/usr/bin/make -f
#
# Debian Installer system makefile.
# Copyright 2001 by Joey Hess <joeyh@debian.org>.
# Licensed under the terms of the GPL.
#
# This makefile builds a debian-installer system and bootable images from 
# a collection of udebs which it downloads from a Debian archive. See
# README for details.

# The kernel version to use on the boot floppy.
KVERS=2.4.0-di

# The type of system to build. Determines what udebs are unpacked into
# the system. See the .list files for various types. You may want to
# override this on the command line.
TYPE=net

# List here any extra udebs that are not in the list file but that
# should still be included on the system.
EXTRAS=""

# set DEBUG to y if you want to get the source for and compile 
# debug versions of the needed udebs
DEBUG=n

# Filename of initrd to create.
INITRD=$(TYPE)-initrd.gz

# How big a floppy image should I make? (in kilobytes)
FLOPPY_SIZE=1440

# The floppy image to create.
FLOPPY_IMAGE=$(TYPE)-$(FLOPPY_SIZE).img

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
	-o Dir::Cache=$(CWD)$(APTDIR)/cache \

# Get the list of udebs to install. Comments are allowed in the lists.
UDEBS=$(shell grep --no-filename -v ^\# lists/base lists/$(TYPE)) $(EXTRAS)

DPKGDIR=$(TREE)/var/lib/dpkg
TEMP=./tmp
TMP_MNT=./mnt/$(TREE)

# Build tree location.
TREE=$(TEMP)/tree

# This is the kernel image that we will boot from.
KERNEL=$(TEMP)/vmlinuz

build: demo_clean reduced_tree stats

demo:
	sudo chroot $(TREE) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(TREE) bin/sh -c "export DEBCONF_FRONTEND=text DEBCONF_DEBUG=5; /usr/bin/debconf-loadtemplate debian /var/lib/dpkg/info/*.templates; /usr/share/debconf/frontend /usr/bin/main-menu"
	$(MAKE) demo_clean

shell:
	mkdir -p $(TREE)/proc 
	sudo chroot $(TREE) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(TREE) bin/sh

demo_clean:
	-if [ -e $(TREE)/proc/self ]; then \
		sudo chroot $(TREE) bin/sh -c "if mount | grep ^proc ; then bin/umount /proc ; fi" &> /dev/null; \
		sudo chroot $(TREE) bin/sh -c "rm -rf /etc /var"; \
	fi

clean:
	dh_clean
	rm -f $(FLOPPY_IMAGE) $(INITRD)
	rm -rf $(TREE) $(APTDIR) $(UDEBDIR) $(TEMP)

# Get all required udebs and put in UDEBDIR.
get_udebs:
	mkdir -p $(APTDIR)/state/lists/partial
	mkdir -p $(APTDIR)/cache/archives/partial
	$(APT_GET) update
	$(APT_GET) autoclean
	# If there are local udebs, remove them from the list of things to
	# get. Then get all the udebs that are left to get.
	needed="$(UDEBS)"; \
	for file in `find $(LOCALUDEBDIR) -name "*_*" -printf "%f\n" 2>/dev/null`; do \
		package=`echo $$file | cut -d _ -f 1`; \
		needed=`echo $$needed | sed "s/$$package *//"`; \
	done; \
	if [ $(DEBUG) = y ] ; then \
		mkdir -p $(DEBUGUDEBDIR); \
		cd $(DEBUGUDEBDIR); \
		export DEB_BUILD_OPTIONS="debug"; \
		$(APT_GET) source --build --yes $$needed; \
		cd ..; \
	else \
		$(APT_GET) -dy install $$needed; \
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

# Build the installer tree.
reduced_tree: tree lib_reduce status_reduce
$(TREE): tree
tree: get_udebs
	dh_testroot

	# This build cannot be restarted, because dpkg gets confused.
	rm -rf $(TREE)
	# Set up the basic files [u]dpkg needs.
	mkdir -p $(DPKGDIR)/info
	touch $(DPKGDIR)/status
	# Only dpkg needs this stuff, so it can be removed later.
	mkdir -p $(DPKGDIR)/updates/
	touch $(DPKGDIR)/available
	# Unpack the udebs with dpkg. This command must run as root or fakeroot.
	dpkg --root=$(TREE) --unpack $(UDEBDIR)/*.udeb
	# Clean up after dpkg.
	rm -rf $(DPKGDIR)/updates
	rm -f $(DPKGDIR)/available $(DPKGDIR)/*-old $(DPKGDIR)/lock
	mkdir -p $(TREE)/lib/modules/$(KVERS)/
	depmod -q -a -b $(TREE)/ $(KVERS)
	# Move the kernel image out of the way, into a temp directory
	# for use later. We don't need it bloating our image!
	mv -f $(TREE)/boot/vmlinuz $(KERNEL)
	-rmdir $(TREE)/boot/

tarball: reduced_tree
	tar czf $(TYPE)-debian-installer.tar.gz $(TREE)

# Make sure that the temporary mountpoint exists and is not occupied.
tmp_mount:
	dh_testroot
	if mount | grep -q $(TMP_MNT) && ! umount $(TMP_MNT) ; then \
		echo "Error unmounting $(TMP_MNT)" 2>&1 ; \
		exit 1; \
	fi
	mkdir -p $(TMP_MNT)

# Create a compressed image of the root filesystem.
# 1. make a temporary file large enough to fit the filesystem.
# 2. mount that file via the loop device, create a filesystem on it
# 3. copy over the root filesystem
# 4. unmount the file, compress it
#
# TODO: get rid of this damned fuzz factor!
$(INITRD): initrd
initrd: FUZZ=127
initrd: TMP_FILE=$(TEMP)/image.tmp
initrd: tmp_mount reduced_tree
	dh_testroot
	rm -f $(TMP_FILE)
	install -d $(TEMP)
	dd if=/dev/zero of=$(TMP_FILE) bs=1k count=`expr $$(du -s $(TREE) | cut -f 1) + $(FUZZ)`
	# FIXME: 2000 bytes/inode (choose that better?)
	mke2fs -F -m 0 -i 2000 -O sparse_super $(TMP_FILE)
	mount -t ext2 -o loop $(TMP_FILE) $(TMP_MNT)
	cp -a $(TREE)/* $(TMP_MNT)/
	umount $(TMP_MNT)
	dd if=$(TMP_FILE) bs=1k | gzip -v9 > $(INITRD)

# Create a bootable floppy image. i386 specific. FIXME
# 1. make a dos filesystem image
# 2. copy over kernel, initrd
# 3. install syslinux
$(FLOPPY_IMAGE): floppy_image
floppy_image: initrd tmp_mount
	dh_testroot
	
	dd if=/dev/zero of=$(FLOPPY_IMAGE) bs=1k count=$(FLOPPY_SIZE)
	mkfs.msdos -i deb00001 -n 'Debian Installer' $(FLOPPY_IMAGE)
	mount -t msdos -o loop $(FLOPPY_IMAGE) $(TMP_MNT)
	
	cp $(KERNEL) $(TMP_MNT)/LINUX
	cp $(INITRD) $(TMP_MNT)/initrd.gz
	
	cp syslinux.cfg $(TMP_MNT)/
	todos $(TMP_MNT)/syslinux.cfg
# This number is used later for stats. There's gotta be a better way.
	df -h $(TMP_MNT) | tail -1 | sed 's/[^ ]* //' | awk 'END { print $$3 }' > $(TEMP)/.floppy_free_stat
	umount $(TMP_MNT)
	syslinux $(FLOPPY_IMAGE)

# Write image to floppy
boot_floppy: $(FLOPPY_IMAGE)
	dd if=$(FLOPPY_IMAGE) of=/dev/fd0

# Library reduction.
lib_reduce:
	mkdir -p $(TREE)/lib
	mklibs.sh -v -d $(TREE)/lib `find $(TREE) -type f -perm +0111 -o -name '*.so'`
	# Now we have reduced libraries installed .. but they are
	# not listed in the status file. This nasty thing puts them in,
	# and alters their names to end in -reduced to indicate that
	# they have been modified.
	for package in $$(dpkg -S `find debian-installer/lib -type f -not -name '*.o'| \
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

COMPRESSED_SZ=$(shell expr $(shell tar cz $(TREE) | wc -c) / 1024)
stats: tree
	@echo
	@echo System stats
	@echo ------------
	@echo Installed udebs: $(UDEBS)
	@echo Total system size: $(shell du -h -s $(TREE) | cut -f 1)
	@echo Compresses to: $(COMPRESSED_SZ)k
	@echo Single Floppy kernel must be less than: ~$(shell expr $(FLOPPY_SIZE) - $(COMPRESSED_SZ) )k
	@if [ -e $(TEMP)/.floppy_free_stat ]; then \
		echo Single net floppy currently has `cat $(TEMP)/.floppy_free_stat` free!; \
	fi
# Add your interesting stats here.


# Upload a daily build to klecker. If you're not Joey Hess, you probably
# don't want to use this grungy code, at least not without overrideing
# this:
UPLOAD_DIR=klecker.debian.org:~/public_html/debian-installer/daily/
daily_build:
	fakeroot $(MAKE) tarball > log 2>&1
	scp -q -B log $(UPLOAD_DIR)
	scp -q -B ../debian-installer.tar.gz \
		$(UPLOAD_DIR)/debian-installer-$(shell date +%Y%m%d).tar.gz
	rm -f log

