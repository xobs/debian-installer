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

# set DEBUG to y if you want to get the source for and compile 
# debug versions of the needed udebs
DEBUG=n

# Build tree location.
DEST=debian-installer

CWD:=$(shell pwd)/
# Directory apt uses for stuff.
APTDIR=apt

# Directory udebs are placed in.
UDEBDIR=udebs

# Local directory that is searched for udebs, to avoid downloading.
# (Or for udebs that are not yet available for download.)
LOCALUDEBDIR=localudebs

# Directory where debug versions of udebs will be built.
DEBUGUDEBDIR=debugudebs

# Figure out which sources.list to use. The .local one is preferred,
# so you can set up a locally preferred one (and not accidentially cvs
# commit it).
ifeq ($(wildcard sources.list.local),sources.list.local)
SOURCES_LIST=sources.list.local
else
SOURCES_LIST=sources.list
endif

# Add to PATH so dpkg will always work
PATH:=$(PATH):/usr/sbin:/sbin:.

# All these options makes apt read the right sources list, and
# use APTDIR for everything so it need not run as root.
APT_GET=apt-get --assume-yes \
	-o Dir::Etc::sourcelist=$(CWD)$(SOURCES_LIST) \
	-o Dir::State=$(CWD)$(APTDIR)/state \
	-o Debug::NoLocking=true \
	-o Dir::Cache=$(CWD)$(APTDIR)/cache \


# Comments are allowed in the lists.
UDEBS=$(shell grep --no-filename -v ^\# lists/base lists/$(TYPE)) $(EXTRAS)

DPKGDIR=$(DEST)/var/lib/dpkg
TMPDIR=./tmp

build: demo_clean tree lib_reduce status_reduce stats

# For now, just build a demo tarball. Later, this should build actual bootable
# images.
image: build
	tar czf ../debian-installer.tar.gz $(DEST)

demo:
	sudo chroot $(DEST) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(DEST) bin/sh -c "export DEBCONF_FRONTEND=text DEBCONF_DEBUG=5; /usr/bin/debconf-loadtemplate debian /var/lib/dpkg/info/*.templates; /usr/share/debconf/frontend /usr/bin/main-menu"
	$(MAKE) demo_clean


shell:
	mkdir -p $(DEST)/proc 
	sudo chroot $(DEST) bin/sh -c "if ! mount | grep ^proc ; then bin/mount proc -t proc /proc; fi"
	sudo chroot $(DEST) bin/sh

demo_clean:
	-if [ -e $(DEST)/proc/self ]; then \
		sudo chroot $(DEST) bin/sh -c "if mount | grep ^proc ; then bin/umount /proc ; fi" &> /dev/null; \
		sudo chroot $(DEST) bin/sh -c "rm -rf /etc /var"; \
	fi


clean:
	dh_clean
	rm -rf $(DEST) $(APTDIR) $(UDEBDIR) $(TMPDIR)

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

# This is a list of the devices we want to create
DEVS=console kmem mem null ram0 ram tty1 tty2 tty3 tty4 hda hdb hdc hdd fd0
PROTOTYPE_ROOTFS=rootfs

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
	mkdir $(DEST)/dev $(DEST)/proc $(DEST)/mnt $(DEST)/var/log
	cp -dpR $(PROTOTYPE_ROOTFS)/* $(DEST)
	find $(DEST) -depth -type d -path "*CVS*" -exec rm -rf {} \;
	$(foreach DEV, $(DEVS), \
	(cp -dpR /dev/$(DEV) $(DEST)/dev/ ) ; )
	# TODO: configure some of the packages?

# Much of this information was taken from
# http://www.linuxdoc.org/HOWTO/Bootdisk-HOWTO/

ROOT_FS_SIZE=`du -s $(DEST) | cut -f 1`

# this is the temp file we are going to mount via the loop back device 
TMP_IMAGE=$(TMPDIR)/$(DEST)

# this is where we'll mount the rootfs
ROOT_IMAGE=./mnt/$(DEST)

rootfs.gz:
	dh_testroot
	rm -f $(TMP_IMAGE)
	if mount | grep $(ROOT_IMAGE) ; then \
		if ! umount $(ROOT_IMAGE) ; then \
			echo "Error unmounting $(ROOT_IMAGE)" ; \
	        exit 1; \
		fi; \
	fi; \

	mkdir -p $(ROOT_IMAGE)

	# make a temporary file, all zeros, big enough to fit root filsystem
	install -d $(TMPDIR)
	dd if=/dev/zero of=$(TMP_IMAGE) bs=1k count=$(ROOT_FS_SIZE)

	# make filesystem, don't reserve any space, 2000 bytes/inode
	mke2fs -F -q -m 0 -i 2000 $(TMP_IMAGE)
	mount -t ext2 -o loop $(TMP_IMAGE) $(ROOT_IMAGE)
	# copy the filesystem we created onto the disk image
	cp -a $(DEST)/* $(ROOT_IMAGE)/
	# give runtime linker clues
	ldconfig -r $(ROOT_IMAGE)
	umount $(ROOT_IMAGE)
	dd if=$(TMP_IMAGE)  bs=1k | gzip -v9 > rootfs.gz


# This is the kernel you want on the bootdisk.
KERNEL=vmlinuz

# kernel blocks is size of kernel + 50, this could be optimized 
KERNEL_BLOCKS=$(shell SIZE=`ls -s $(KERNEL) | cut -f 2 -d " "`; \
	let SIZE=$$SIZE+50 ; echo $$SIZE)
# where we are making the boot disk
FD_DEV=/dev/fd0

# where we should mount it
FD_MNT=/floppy

# use to tell the kernel where the ramdisk will be
RAMDISK_WORD=$(shell let SIZE=$(KERNEL_BLOCKS)+16384 ; echo $$SIZE)


boot_floppy: rootfs.gz $(KERNEL)
	dh_testroot
	if mount | grep $(FD_MNT) ; then \
		if ! umount $(FD_MNT) ; then \
			echo "Error unmounting $(FD_MNT)" ; \
	        exit 1; \
		fi; \
	fi; \

	mkdir -p $(FD_MNT)
	mke2fs -i 8192 -m 0 $(FD_DEV) $(KERNEL_BLOCKS)
	mount $(FD_DEV) $(FD_MNT)
	rm -rf $(FD_MNT)/lost+found
	mkdir $(FD_MNT)/{boot,dev}
	cp -R /dev/{null,fd0} $(FD_MNT)/dev
	cp /boot/boot.b $(FD_MNT)/boot
	cp bdlilo.conf $(KERNEL) $(FD_MNT)
	lilo -v -C bdlilo.conf -r $(FD_MNT) 
	# tell the kernel where the ramdisk is
	rdev -r $(FD_MNT)/$(KERNEL)  $(RAMDISK_WORD)
	umount $(FD_MNT)
	# copy over the ramdisk onto the floppy
	dd if=rootfs.gz of=$(FD_DEV) bs=1k seek=$(KERNEL_BLOCKS)


# Library reduction.
lib_reduce:
	mkdir -p $(DEST)/lib
	mklibs.sh -v -d $(DEST)/lib `find $(DEST) -type f -perm +0111 -o -name '*.so'`
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


COMPRESSED_SZ=$(shell expr $(shell tar cz $(DEST) | wc -c) / 1024)
stats:
	@echo
	@echo System stats
	@echo ------------
	@echo Installed udebs: $(UDEBS)
	@echo Total system size: $(shell du -h -s $(DEST) | cut -f 1)
	@echo Compresses to: $(COMPRESSED_SZ)k
	@echo Single Floppy kernel must be less than: ~$(shell expr 1400 - $(COMPRESSED_SZ) )k
# Add your interesting stats here.

# Upload a daily build to klecker. If you're not Joey Hess, you probably
# don't want to use this grungy code, at least not without overrideing
# this:
UPLOAD_DIR=klecker.debian.org:~/public_html/debian-installer/daily/
daily_build:
	fakeroot $(MAKE) image > log 2>&1
	scp -q -B log $(UPLOAD_DIR)
	scp -q -B ../debian-installer.tar.gz \
		$(UPLOAD_DIR)/debian-installer-$(shell date +%Y%m%d).tar.gz
	rm -f log

