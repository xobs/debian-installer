#!/usr/bin/make -f
#
# Debian Installer system makefile.
# Copyright 2001, 2002 by Joey Hess <joeyh@debian.org>.
# Licensed under the terms of the GPL.
#
# This makefile builds a debian-installer system and bootable images from 
# a collection of udebs which it downloads from a Debian archive. See
# README for details.

DEB_HOST_ARCH = $(shell dpkg-architecture -qDEB_HOST_ARCH)
DEB_HOST_GNU_CPU = $(shell dpkg-architecture -qDEB_HOST_GNU_CPU)
DEB_HOST_GNU_SYSTEM = $(shell dpkg-architecture -qDEB_HOST_GNU_SYSTEM)

# Include main config
include config/main

# Include arch configs
include config/arch/$(DEB_HOST_GNU_SYSTEM)
include config/arch/$(DEB_HOST_GNU_SYSTEM)-$(DEB_HOST_GNU_CPU)

# Include type configs
-include config/type/$(TYPE)
-include config/type/$(TYPE)-$(DEB_HOST_GNU_SYSTEM)

# Include directory config
include config/dir

ifeq (,$(filter $(TYPE),type $(TYPES_SUPPORTED)))
ERROR_TYPE = 1
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
UDEBS = \
	$(shell grep --no-filename -v ^\# \
			pkg-lists/base \
			pkg-lists/$(TYPE)/common \
			`if [ -f pkg-lists/$(TYPE)/$(DEB_HOST_ARCH) ]; then echo pkg-lists/$(TYPE)/$(DEB_HOST_ARCH); fi` \
		| sed -e 's/^\(.*\)$${kernel:Version}\(.*\)$$/$(foreach VERSION,$(KERNELIMAGEVERSION),\1$(VERSION)\2\n)/g' \
	) $(EXTRAS)

ifeq ($(TYPE),floppy)
# List of additional udebs for driver floppy(ies). At the moment there is only one additional driver floppy needed
DRIVERFD_UDEBS = \
	$(shell for target in $(EXTRA_FLOPPIES) ; do  grep --no-filename -v ^\# \
		pkg-lists/$$target/common \
		`if [ -f pkg-lists/$$target/$(DEB_HOST_ARCH) ]; then echo pkg-lists/$$target/$(DEB_HOST_ARCH); fi` \
		| sed -e 's/^\(.*\)$${kernel:Version}\(.*\)$$/$(foreach VERSION,$(KERNELIMAGEVERSION),\1$(VERSION)\2\n)/g'  ; done )
endif

# Scratch directory.
BASE_TMP=./tmp/
# Per-type scratch directory.
TEMP=$(BASE_TMP)$(TYPE)

# Build tree location.
TREE=$(TEMP)/tree

# CD Image tree location
CD_IMAGE_TREE=$(TEMP)/cd_image_tree

DPKGDIR=$(TREE)/var/lib/dpkg
DRIVEREXTRASDIR=$(TREE)/driver-tmp
DRIVEREXTRASDPKGDIR=$(DRIVEREXTRASDIR)/var/lib/dpkg

TMP_MNT:=$(shell pwd)/mnt

ifdef ERROR_TYPE
%:
	@echo "unsupported type"
	@echo "type: $(TYPE)"
	@echo "supported types: $(TYPES_SUPPORTED)"
	@exit 1
endif

build: tree_umount tree $(TREE)/unifont.bgf $(EXTRA_TARGETS) stats

image: arch-image $(TREE)/unifont.bgf $(EXTRA_IMAGES) 

# Include arch targets
-include make/arch/$(DEB_HOST_GNU_SYSTEM)
include make/arch/$(DEB_HOST_GNU_SYSTEM)-$(DEB_HOST_GNU_CPU)

tree_mount: tree
	-@sudo /bin/mount -t proc proc $(TREE)/proc
ifndef USERDEVFS
	-@sudo /bin/mount -t devfs dev $(TREE)/dev
else
	-@sudo chroot $(TREE) /usr/bin/update-dev
endif




tree_umount:
ifndef USERDEVFS
	-@if [ -d $(TREE)/dev ] ; then sudo /bin/umount $(TREE)/dev 2>/dev/null ; fi
endif
	-@if [ -d $(TREE)/proc ] ; then sudo /bin/umount $(TREE)/proc 2>/dev/null ; fi

demo: tree
	$(MAKE) tree_mount
	# Restart syslogd, watching the log fd inside the chroot too.
	/etc/init.d/sysklogd stop
	# -a must have the full path
	start-stop-daemon --start --quiet --exec /sbin/syslogd -- -a `pwd`/$(TREE)/dev/log
	SYSLOGD="-a $(TREE)/dev/log" /etc/init.d/sysklogd start
	-@[ -f questions.dat ] && cp -f questions.dat $(TREE)/var/lib/cdebconf/
	-@sudo chroot $(TREE) bin/sh -c "export TERM=linux; export DEBCONF_DEBUG=5; /usr/bin/debconf-loadtemplate debian /var/lib/dpkg/info/*.templates; exec /usr/share/debconf/frontend /usr/bin/main-menu"
	/etc/init.d/sysklogd stop
	/etc/init.d/sysklogd start
	$(MAKE) tree_umount

shell: tree
	$(MAKE) tree_mount
	-@sudo chroot $(TREE) bin/sh
	$(MAKE) tree_umount

uml: $(INITRD)
	-linux initrd=$(INITRD) root=/dev/rd/0 ramdisk_size=8192 con=fd:0,fd:1 devfs=mount

demo_clean: tree_umount

clean: demo_clean tmp_mount debian/control
	if [ "$(USER_MOUNT_HACK)" ] ; then \
	    if mount | grep -q "$(USER_MOUNT_HACK)"; then \
	        umount "$(USER_MOUNT_HACK)";\
	    fi ; \
	fi
	rm -rf $(TREE) 2>/dev/null $(TEMP)/modules $(NETDRIVERS) || sudo rm -rf $(TREE) $(TEMP)/modules $(NETDRIVERS)
	dh_clean
	rm -f *-stamp
	rm -rf $(UDEBDIR) $(EXTRAUDEBDIR) $(TMP_MNT) debian/build
	rm -rf $(DEST)/$(TYPE)-* || sudo rm -rf $(DEST)/$(TYPE)-*
	rm -f unifont-reduced-$(TYPE).bdf
	$(foreach NAME,$(KERNELNAME), \
		rm -f $(TEMP)/$(NAME); )

reallyclean: clean
	rm -rf $(APTDIR) $(DEST) $(BASE_TMP) wget-cache $(SOURCEDIR)
	rm -f diskusage*.txt missing.txt all-*.utf *.bdf

# prefetch udebs
# If we are building a correct debian-installer source tree, we will want all the
# sources. So go fetch.
fetch-sources: $(SOURCEDIR)/udeb-sources-stamp
$(SOURCEDIR)/udeb-sources-stamp:
	mkdir -p $(APTDIR)/state/lists/partial
	mkdir -p $(APTDIR)/cache/archives/partial
	$(APT_GET) update
	$(APT_GET) autoclean
	needed="$(UDEBS) $(DRIVERFD_UDEBS)"; \
        for file in `find $(LOCALUDEBDIR) -name "*_*" -printf "%f\n" 2>/dev/null`; do \
		package=`echo $$file | cut -d _ -f 1`; \
		needed=`echo " $$needed " | sed "s/ $$package */ /"` ; \
	done; \
	mkdir -p $(SOURCEDIR); \
	cd $(SOURCEDIR); \
	$(APT_GET) source --yes $$needed; \
	rm -f *.dsc *.gz ; \
	touch udeb-sources-stamp ; \
	cd .. 


#  From the sources, 
#  Compile up all the udebs and place them in udebs
#  This is used by build-installer to avoid downloading from net.
compile-udebs: compiled-stamp
compiled-stamp: $(SOURCEDIR)/udeb-sources-stamp
	mkdir -p $(APTDIR)/cache/archives
	for d in ` ls $(SOURCEDIR) | grep -v stamp ` ; do  \
		 ( unset MAKEFLAGS ; unset MAKELEVEL ; cd $(SOURCEDIR)/$$d ; dpkg-buildpackage -uc -us || true  ) ; \
	done 
	mv $(SOURCEDIR)/*.udeb $(APTDIR)/cache/archives
	touch compiled-stamp

# 
# Get all required udebs and put in UDEBDIR.
get_udebs: $(TYPE)-get_udebs-stamp
$(TYPE)-get_udebs-stamp:
	mkdir -p $(APTDIR)/state/lists/partial
	mkdir -p $(APTDIR)/cache/archives/partial
	$(APT_GET) update
	$(APT_GET) autoclean
	# If there are local udebs, remove them from the list of things to
	# get. Then get all the udebs that are left to get.
	# Note that the trailing blank on the next line is significant. It
	# makes the sed below always work.
	needed="$(UDEBS) $(DRIVERFD_UDEBS) "; \
	for file in `find $(LOCALUDEBDIR) -name "*_*" -printf "%f\n" 2>/dev/null`; do \
		package=`echo $$file | cut -d _ -f 1`; \
		needed=`echo " $$needed " | sed "s/ $$package / /"`; \
	done; \
	if [ "$(DEBUG)" = y ] ; then \
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
	rm -rf $(EXTRAUDEBDIR)
	mkdir -p $(EXTRAUDEBDIR)
	lnpkg() { \
		local pkg=$$1; local dir=$$2 debdir=$$3; \
		local L1="`echo $$dir/$$pkg\_*`"; \
		local L2="`echo $$L1 | sed -e 's, ,,g'`"; \
		if [ "$$L1" != "$$L2" ]; then \
			echo "Duplicate package $$pkg in $$dir/"; \
			exit 1; \
		fi; \
		if [ -e $$L1 ]; then \
			ln -f $$dir/$$pkg\_* $$debdir/$$pkg.udeb; \
		fi; \
	}; \
	for package in $(UDEBS) ; do \
		lnpkg $$package $(APTDIR)/cache/archives $(UDEBDIR); \
		lnpkg $$package $(LOCALUDEBDIR) $(UDEBDIR); \
		lnpkg $$package $(DEBUGUDEBDIR) $(UDEBDIR); \
		if ! [ -e $(UDEBDIR)/$$package.udeb ]; then \
			echo "Needed $$package not found (looked in $(APTDIR)/cache/archives/, $(LOCALUDEBDIR)/, $(DEBUGUDEBDIR)/)"; \
			exit 1; \
		fi; \
	done ; \
	for package in $(DRIVERFD_UDEBS) ; do \
                lnpkg $$package $(APTDIR)/cache/archives $(EXTRAUDEBDIR); \
		lnpkg $$package $(LOCALUDEBDIR) $(EXTRAUDEBDIR); \
                lnpkg $$package $(DEBUGUDEBDIR) $(EXTRAUDEBDIR); \
                if ! [ -e $(EXTRAUDEBDIR)/$$package.udeb ]; then \
                        echo "Needed $$package not found (looked in $(APTDIR)/cache/archives/, $(LOCALUDEBDIR)/, $(DEBUGUDEBDIR)/)"; \
                        exit 1; \
                fi; \
        done

	touch $(TYPE)-get_udebs-stamp


# Build the installer tree.
tree: $(TYPE)-tree-stamp
$(TYPE)-tree-stamp: $(TYPE)-get_udebs-stamp debian/control
	dh_testroot

	dpkg-checkbuilddeps

	# This build cannot be restarted, because dpkg gets confused.
	rm -rf $(TREE) $(TEMP)/modules
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
	oldsize=0; oldblocks=0; oldcount=0; for udeb in $(UDEBDIR)/*.udeb ; do \
		pkg=`basename $$udeb` ; \
		dpkg --force-overwrite --root=$(TREE) --unpack $$udeb ; \
		newsize=`du -bs $(TREE) | awk '{print $$1}'` ; \
		newblocks=`du -s $(TREE) | awk '{print $$1}'` ; \
		newcount=`find $(TREE) -type f | wc -l | awk '{print $$1}'` ; \
		usedsize=`echo $$newsize - $$oldsize | bc`; \
		usedblocks=`echo $$newblocks - $$oldblocks | bc`; \
		usedcount=`echo $$newcount - $$oldcount | bc`; \
		version=`dpkg-deb --info $$udeb | grep Version: | awk '{print $$2}'` ; \
		echo " $$usedsize B - $$usedblocks blocks - $$usedcount files used by pkg $$pkg (version $$version )" >>diskusage-$(TYPE).txt;\
		oldsize=$$newsize ; \
		oldblocks=$$newblocks ; \
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
	$(foreach VERSION,$(KERNELVERSION), \
		mkdir -p $(TREE)/lib/modules/$(VERSION)/kernel; \
		depmod -q -a -b $(TREE)/ $(VERSION); )
	# These files depmod makes are used by hotplug, and we shouldn't
	# need them, yet anyway.
	find $(TREE)/lib/modules/ -name 'modules*' \
		-not -name modules.dep -not -type d | xargs rm -f
	# Create a dev tree
	mkdir -p $(TREE)/dev

	# Move the kernel image out of the way, into a temp directory
	# for use later. We don't need it bloating our image!
	$(foreach NAME,$(KERNELNAME), \
		mv -f $(TREE)/boot/$(NAME) $(TEMP); )
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

ifeq ($(TYPE),floppy)
	# Unpack additional driver disks, so mklibs runs on them too.
	rm -rf $(DRIVEREXTRASDIR)
	mkdir -p $(DRIVEREXTRASDIR)
	mkdir -p $(DRIVEREXTRASDPKGDIR)/info $(DRIVEREXTRASDPKGDIR)/updates
	touch $(DRIVEREXTRASDPKGDIR)/status $(DRIVEREXTRASDPKGDIR)/available
	for udeb in $(EXTRAUDEBDIR)/*.udeb ; do \
		dpkg --force-overwrite --root=$(DRIVEREXTRASDIR) --unpack $$udeb; \
	done
endif

	# Library reduction.
	mkdir -p $(TREE)/lib
	$(MKLIBS) -v -d $(TREE)/lib --root=$(TREE) `find $(TEMP) -type f -perm +0111 -o -name '*.so'`

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
	# the font.  Using strings is not the best way, but no better suggestion
	# has been made yet.
	cp graphic.utf all-$(TYPE).utf
ifeq ($(TYPE),floppy)
	cat $(DRIVEREXTRASDPKGDIR)/info/*.templates >> all-$(TYPE).utf
endif
	cat $(DPKGDIR)/info/*.templates >> all-$(TYPE).utf
	find $(TREE) -type f | xargs strings >> all-$(TYPE).utf

ifeq ($(TYPE),floppy)
	# Remove additional driver disk contents now that we're done with
	# them.
	rm -rf $(DRIVEREXTRASDIR)
endif
	# Tree target ends here. Whew!


unifont-reduced-$(TYPE).bdf: all-$(TYPE).utf
	# Need to use an UTF-8 based locale to get reduce-font working.
	# Any will do.  en_IN seem fine and was used by boot-floppies
	# reduce-font is part of package libbogl-dev
	# unifont.bdf is part of package bf-utf-source
	# The locale must be generated after installing the package locales
	LC_ALL=en_IN.UTF-8 reduce-font /usr/src/unifont.bdf < all-$(TYPE).utf > $@.tmp
	mv $@.tmp $@

$(TREE)/unifont.bgf: unifont-reduced-$(TYPE).bdf
	# bdftobogl is part of package libbogl-dev
	bdftobogl -b unifont-reduced-$(TYPE).bdf > $@.tmp
	mv $@.tmp $@

# Build the driver floppy image
$(EXTRA_TARGETS) : %-stamp : floppy-get_udebs-stamp
	mkdir -p  ${TEMP}/$*
	for file in $(shell grep --no-filename -v ^\#  pkg-lists/$*/common \
		`if [ -f pkg-lists/$*/$(DEB_HOST_ARCH) ]; then echo pkg-lists/$*/$(DEB_HOST_ARCH); fi` \
	  	| sed -e 's/^\(.*\)$${kernel:Version}\(.*\)$$/$(foreach VERSION,$(KERNELIMAGEVERSION),\1$(VERSION)\2\n)/g' ) ; do \
			cp $(EXTRAUDEBDIR)/$$file* ${TEMP}/$*  ;	done
	touch $@


$(EXTRA_IMAGES) : $(DEST)/%-image.img :  $(EXTRA_TARGETS)
	rm -f $@
	install -d $(TEMP)
	install -d $(DEST)
	set -e; if [ $(INITRD_FS) = ext2 ]; then \
		genext2fs -d $(TEMP)/$* -b $(FLOPPY_SIZE) -r 0  $@; \
        elif [ $(INITRD_FS) = romfs ]; then \
                genromfs -d $(TEMP)/$* -f $@; \
        else \
                echo "Unsupported filesystem type"; \
                exit 1; \
        fi;


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
initrd: $(INITRD)
$(INITRD): TMP_FILE=$(TEMP)/image.tmp
$(INITRD):  $(TYPE)-tree-stamp $(TREE)/unifont.bgf
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
	gzip -vc9 $(TMP_FILE) > $(INITRD).tmp
	mv $(INITRD).tmp $(INITRD)

# Write image to floppy
boot_floppy: $(IMAGE)
	install -d $(DEST)
	dd if=$(IMAGE) of=$(FLOPPYDEV)

# Write drivers  floppy
%_floppy: $(DEST)/%-image.img
	install -d $(DEST)
	dd if=$< of=$(FLOPPYDEV)

# If you're paranoid (or things are mysteriously breaking..),
# you can check the floppy to make sure it wrote properly.
# This target will fail if the floppy doesn't match the floppy image.
boot_floppy_check: floppy_image
	cmp $(FLOPPYDEV) $(IMAGE)

stats: tree $(EXTRA_TARGETS) general-stats $(EXTRA_STATS)

COMPRESSED_SZ=$(shell expr $(shell tar czf - $(TREE) | wc -c) / 1024)
KERNEL_SZ=$(shell expr \( $(foreach NAME,$(KERNELNAME),$(shell du -b $(TEMP)/$(NAME) | cut -f 1) +) 0 \) / 1024)
general-stats:
	@echo
	@echo "System stats for $(TYPE)"
	@echo "-------------------------"
	@echo "Installed udebs: $(UDEBS)"
	@echo -n "Total system size: $(shell du -h -s $(TREE) | cut -f 1)"
	@echo -n " ($(shell du -h --exclude=modules -s $(TREE)/lib | cut -f 1) libs, "
	@echo "$(shell du -h -s $(TREE)/lib/modules | cut -f 1) kernel modules)"
	@echo "Initrd size: $(COMPRESSED_SZ)k"
	@echo "Kernel size: $(KERNEL_SZ)k"
ifneq (,$(FLOPPY_SIZE))
	@echo "Free space: $(shell expr $(FLOPPY_SIZE) - $(KERNEL_SZ) - $(COMPRESSED_SZ))k"
endif
	@echo "Disk usage per package:"
	@sed 's/^/  /' < diskusage-$(TYPE).txt
# Add your interesting stats here.

SZ=$(shell expr $(shell du -b $(TEMP)/$*  | cut -f 1 ) / 1024)
$(EXTRA_STATS) : %-stats:  
	echo Calculating spec stats
	@echo
	@echo "$* size: $(SZ)k"
ifneq (,$(FLOPPY_SIZE))
	@echo "Free space: $(shell expr $(FLOPPY_SIZE) - $(SZ))k"
endif
	@echo "Disk usage per package on net_drivers:"
	@ls -l $(TEMP)/$*/*.udeb
	@echo


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
	$(MAKE) image >> $(DEST)/$(TYPE).log 2>&1
	$(MAKE) stats | grep -v ^make > $(DEST)/$(TYPE).info
	echo "Tree comparison" >> $(DEST)/$(TYPE).info
	echo "" >> $(DEST)/$(TYPE).info
	if [ -d $(TYPE)-oldtree ]; then \
		./treecompare $(TYPE)-oldtree $(TREE) >> $(DEST)/$(TYPE).info; \
	fi
	scp -q -B $(DEST)/$(TYPE).log $(UPLOAD_DIR)
	scp -q -B $(DEST)/$(TYPE)-debian-installer.tar.gz \
		$(UPLOAD_DIR)/$(TYPE)-debian-installer-$(shell date +%Y%m%d).tar.gz
	scp -q -B $(IMAGE) $(INITRD) $(UPLOAD_DIR)/images/
	scp -q -B $(DEST)/$(TYPE).info \
		$(UPLOAD_DIR)/$(TYPE).info-$(shell date +%Y%m%d)
	echo "Type: $(TYPE)" >> $(DEST)/info
	cat $(DEST)/$(TYPE).info >> $(DEST)/info
	rm -rf $(TYPE)-oldtree
	-mv $(TREE) $(TYPE)-oldtree && rm -f $(TYPE)-tree-stamp

