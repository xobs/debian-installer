#!/usr/bin/make -f
#
# Debian Installer system makefile.
# Copyright 2001-2003 by Joey Hess <joeyh@debian.org> and the d-i team.
# Licensed under the terms of the GPL.
#
# This makefile builds a debian-installer system and bootable images from 
# a collection of udebs which it downloads from a Debian archive. See
# README for details.
#

#
# General layout of our build directory hierarchy
#
# build/config/[<subarch>/][<medium>/][<flavour>/]<leaf-config>
# build/tmp/[<subarch>/][<medium>/][<flavour>/]<build-area>
# build/dest/[<subarch>/][<medium>/][<flavour>-]<images>
#
# Items in brackets can be left out if they are superfluous.
#
# These following <image> names are conventional.
#
# For small changeable media (floppies and the like):
# - boot.img, root.img, driver.img
#
# For single bootable images (e.g. tftp boot images):
# - boot.img
#
# For compressed single bootable images (harddisk or hd emulation):
# - boot.img.gz
#
# If those are not bootable:
# - root.img.gz
#
# Raw kernel images:
# - vmlinux or vmlinuz
#
# Example:
#
# dest/
# |-- cdrom-boot.img
# |-- floppy
# |   |-- access
# |   |   |-- boot.img
# |   |   |-- drivers.img
# |   |   `-- root.img
# |   |-- boot.img
# |   |-- cd-drivers.img
# |   |-- net-drivers.img
# |   `-- root.img
# |-- hd-media-boot.img.gz
# `-- netboot
#     |-- initrd.gz
#     `-- vmlinuz
#

# Add to PATH so dpkg will always work, and so local programs will be found.
PATH := $(PATH):/usr/sbin:/sbin:.

# We don't want this to be run each time we re-enter.
ifndef DEB_HOST_ARCH
DEB_HOST_ARCH = $(shell dpkg-architecture -qDEB_HOST_ARCH)
DEB_HOST_GNU_CPU = $(shell dpkg-architecture -qDEB_HOST_GNU_CPU)
DEB_HOST_GNU_SYSTEM = $(shell dpkg-architecture -qDEB_HOST_GNU_SYSTEM)
export DEB_HOST_ARCH DEB_HOST_GNU_CPU DEB_HOST_GNU_SYSTEM
endif

# We loop over all needed combinations of ARCH, SUBARCH, MEDIUM, FLAVOUR
# via recursive make calls. ARCH is constant, we don't support
# crosscompiling.
ARCH = $(DEB_HOST_ARCH)

#
# By default, we just advertise what we can do.
#
.PHONY: all
all: list

#
# Globally useful variables.
#
targetstring = $(patsubst _%,%,$(if $(SUBARCH),_$(SUBARCH),)$(if $(MEDIUM),_$(MEDIUM),)$(if $(FLAVOUR),_$(FLAVOUR),))
targetdirs = $(subst _,/,$(targetstring))


#
# Configurations for the varying ARCH, SUBARCH, MEDIUM, FLAVOUR.
# For simplicity, we use a similiar tree layout for config/, tmp/
# and dest/.
#
# Cheap trick: if one of the variables isn't defined, we run in
# a non-existing file and ignore it.
#
include config/common
include config/dir
-include config/local
-include config/$(ARCH).cfg
-include config/$(ARCH)/$(SUBARCH).cfg
-include config/$(ARCH)/$(SUBARCH)/$(MEDIUM).cfg
-include config/$(ARCH)/$(SUBARCH)/$(MEDIUM)/$(FLAVOUR).cfg

#
# Useful command sequences
#
define submake
  $(MAKE) --no-print-directory
endef

define recurse_once
  @set -e; $(submake) $(1)_$(2)
endef

define recurse_many
  @set -e; $(foreach var,$($(1)_SUPPORTED),$(submake) $(2)_$(3) $(1)=$(var);)
endef

define recurse
  $(if $($(1)_SUPPORTED),$(call recurse_many,$(1),$(2),$(3)),$(call recurse_once,$(2),$(3)))
endef

define genext2fs-userdevfs
  genext2fs -d $(TREE) -b $(USERDEVFS_SIZE) -r 0 -f userdevfs-dev.txt
endef

define genext2fs
  genext2fs -d $(TREE) -b `expr $$(du -s $(TREE) | cut -f 1) + $$(expr $$(find $(TREE) | wc -l) \* 2)` -r 0
endef

define e2fsck
  e2fsck -fy
endef

define mkcramfs
  mkcramfs $(TREE)
endef

#
# A generic recursion rule
#
.PHONY: all_%
all_%:
	@install -d $(STAMPS)
	$(call recurse,SUBARCH,subarch,$*)

.PHONY: subarch_%
subarch_%:
	$(call recurse,MEDIUM,medium,$*)

.PHONY: medium_%
medium_%:
	$(call recurse,FLAVOUR,flavour,$*)

.PHONY: flavour_%
flavour_%:
	$(if $(targetstring),@$(submake) _$*)

#
# Validate a targetstring, echo env variables for valid ones
#
.PHONY: validate_%
validate_%:
	@set -e; \
	SUBARCH= var='$(subst _, ,$(subst validate_,,$@))'; \
	tmp=$$(echo $$var |sed 's/[ ].*$$//'); \
	[ -z '$(SUBARCH_SUPPORTED)' ] || [ -z "$$tmp" ] || [ -z "$$(echo $(SUBARCH_SUPPORTED) |grep -w $$tmp)" ] || SUBARCH=$$tmp; \
	$(submake) medium_validate SUBARCH=$$SUBARCH var="$$var"

.PHONY: medium_validate
medium_validate:
	@set -e; \
	MEDIUM= var="$(strip $(patsubst $(SUBARCH)%,%,$(var)))"; \
	tmp=$$(echo $$var |sed 's/[ ].*$$//'); \
	[ -z '$(MEDIUM_SUPPORTED)' ] || [ -z "$$tmp" ] || [ -z "$$(echo $(MEDIUM_SUPPORTED) |grep -w $$tmp)" ] || MEDIUM=$$tmp; \
	$(submake) flavour_validate MEDIUM=$$MEDIUM var="$$var"

.PHONY: flavour_validate
flavour_validate:
	@set -e; \
	FLAVOUR= var="$(strip $(patsubst $(MEDIUM)%,%,$(var)))"; \
	tmp=$$(echo $$var |sed 's/[ ].*$$//'); \
	[ -z '$(FLAVOUR_SUPPORTED)' ] || [ -z "$$tmp" ] || [ -z "$$(echo $(FLAVOUR_SUPPORTED) |grep -w $$tmp)" ] || FLAVOUR=$$tmp; \
	$(submake) finish_validate FLAVOUR=$$FLAVOUR var="$$var"

.PHONY: finish_validate
finish_validate:
	@set -e; \
	var="$(strip $(patsubst $(FLAVOUR)%,%,$(var)))"; \
	if [ -z "$$var" ]; then \
		echo SUBARCH=$$SUBARCH MEDIUM=$$MEDIUM FLAVOUR=$$FLAVOUR; \
	else \
		echo SUBARCH= MEDIUM= FLAVOUR=; \
	fi;


#
# List all targets useful for direct invocation.
#
.PHONY: list
list:
	@echo "Useful targets:"
	@echo
	@echo "list"
	@echo "all_build"
	@echo "stats"
	@echo "all_clean"
	@echo "reallyclean"
	@echo
	@$(submake) all_list

.PHONY: _list
_list:
	@set -e; \
	echo build_$(targetstring); \
	echo stats_$(targetstring); \
	$(if $(findstring $(MEDIUM),$(WRITE_MEDIA)),echo write_$(targetstring);) \
	echo clean_$(targetstring); \
	echo rebuild_$(targetstring); \
	echo demo_$(targetstring); \
	echo shell_$(targetstring); \
	echo uml_$(targetstring); \
	echo qemu_$(targetstring); \
	echo


#
# Clean all targets.
#
.PHONY: reallyclean
reallyclean: all_clean
	rm -rf $(APTDIR) $(APTDIR).udeb $(APTDIR).deb $(BASE_DEST) $(BASE_TMP) $(SOURCEDIR) $(DEBUGUDEBDIR)
	rm -f sources.list sources.list.udeb sources.list.deb
	rm -rf $(UDEBDIR) $(STAMPS)

# For manual invocation, we provide a generic clean rule.
.PHONY: clean_%
clean_%:
	@$(submake) _clean $(shell $(submake) $(subst clean_,validate_,$@))
	./update-manifest

# The general clean rule.
.PHONY: _clean
_clean: tree_umount
	@[ -n "$(SUBARCH) $(MEDIUM) $(FLAVOUR)" ] || { echo "invalid target"; false; }
	-rm -f $(STAMPS)tree-unpack-$(targetstring)-stamp $(STAMPS)tree-$(targetstring)-stamp $(STAMPS)extra-$(targetstring)-stamp $(STAMPS)get_udebs-$(targetstring)-stamp
	rm -f $(TEMP)/diskusage.txt
	rm -f $(TEMP)/all.utf
	rm -f $(TEMP)/unifont.bdf $(TREE)/unifont.bgf
	rm -f pkg-lists/standard-udebs pkg-lists/kernel-module-udebs
	rm -f $(TARGET)
	rm -rf $(TEMP)

#
# all_build is provided automagically, but for manual invocation
# we provide a generic build rule.
#
.PHONY: build_%
build_%:
	@install -d $(STAMPS)
	@$(submake) _build $(shell $(submake) $(subst build_,validate_,$@))

# The general build rule.
.PHONY: _build
_build:
	@[ -n "$(SUBARCH) $(MEDIUM) $(FLAVOUR)" ] || { echo "invalid target"; false; }
	@$(submake) tree_umount $(EXTRATARGETS) $(TARGET)

# Convenience rule to clean and build.
.PHONY: rebuild_%
rebuild_%:
	@$(submake) clean_$(subst rebuild_,,$@) build_$(subst rebuild_,,$@)

#
# The general tree target.
# FIXME: This is way too convoluted.
#
$(STAMPS)tree-unpack-$(targetstring)-stamp: $(STAMPS)get_udebs-$(targetstring)-stamp
	dh_testroot
	cd .. && dpkg-checkbuilddeps
	@rm -f $@

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
	echo -n > $(TEMP)/diskusage.txt
	set -e; \
	oldsize=0; oldblocks=0; oldcount=0; for udeb in $(UDEBDIR)/*.udeb ; do \
		if [ -f "$$udeb" ]; then \
			pkg=`basename $$udeb` ; \
			dpkg $(DPKG_UNPACK_OPTIONS) --root=$(TREE) --unpack $$udeb ; \
			newsize=`du -bs $(TREE) | awk '{print $$1}'` ; \
			newblocks=`du -s $(TREE) | awk '{print $$1}'` ; \
			newcount=`find $(TREE) -type f | wc -l | awk '{print $$1}'` ; \
			usedsize=`echo $$newsize - $$oldsize | bc`; \
			usedblocks=`echo $$newblocks - $$oldblocks | bc`; \
			usedcount=`echo $$newcount - $$oldcount | bc`; \
			version=`dpkg-deb --info $$udeb | grep Version: | awk '{print $$2}'` ; \
			echo " $$usedsize B - $$usedblocks blocks - $$usedcount files from $$pkg (version $$version)" >>$(TEMP)/diskusage.txt;\
			oldsize=$$newsize ; \
			oldblocks=$$newblocks ; \
			oldcount=$$newcount ; \
		fi; \
	done
	sort -n < $(TEMP)/diskusage.txt > $(TEMP)/diskusage.txt.new && \
		mv $(TEMP)/diskusage.txt.new $(TEMP)/diskusage.txt
	grep-dctrl -nsPackage,Version '' $(TREE)/var/lib/dpkg/status | \
		perl -nle '$$p = $$_; $$v = <>; chomp $$v; <>; print "$$p $$v"' | \
		sort > $(TEMP_INITRD_LIST)

	# Clean up after dpkg.
	rm -rf $(DPKGDIR)/updates
	rm -f $(DPKGDIR)/available $(DPKGDIR)/*-old $(DPKGDIR)/lock

ifdef KERNELVERSION
	# Set up modules.dep, ensure there is at least one standard dir (kernel
	# in this case), so depmod will use its prune list for archs with no
	# modules.
	#
	set -e; \
	$(foreach VERSION,$(KERNELVERSION), \
		sysmap_name=; sysmap_opt=; \
		if [ -n "$(VERSIONED_SYSTEM_MAP)" ]; then \
			[ ! -e $(TREE)/boot/System.map-$(VERSION) ] || sysmap_name="$(TREE)/boot/System.map-$(VERSION)"; \
		else \
			[ ! -e $(TREE)/boot/System.map ] || sysmap_name="$(TREE)/boot/System.map"; \
		fi; \
		[ -z "$$sysmap_name" ] || sysmap_opt="-F $$sysmap_name"; \
		if [ -d $(TREE)/lib/modules/$(VERSION) ]; then \
			mkdir -p $(TREE)/lib/modules/$(VERSION)/kernel; \
			$(shell ./choose-subarch-env $(VERSION)) depmod $$sysmap_opt -q -a -b $(TREE)/ $(VERSION); \
		fi; \
		[ -z "$$sysmap_name" ] || mv $$sysmap_name $(TEMP);)

	# These files depmod makes are used by hotplug, and we shouldn't
	# need them, yet anyway.
	find $(TREE)/lib/modules/ -name 'modules*' \
		-not -name modules.dep -not -type d | xargs rm -f

	# These files are used to build special kernel images for some
	# subarchitectures. Move them out of the way.
	if [ -d $(TREE)/usr/lib/kernel-image-$(KERNELVERSION) ]; then \
		mv $(TREE)/usr/lib/kernel-image-$(KERNELVERSION) $(TEMP)/lib; \
	fi
endif

ifdef KERNELNAME
	# Move the kernel image out of the way.
	$(foreach name,$(KERNELNAME), \
		mv -f $(TREE)/boot/$(name) $(TEMP)/$(name);)
	rmdir $(TREE)/boot/
endif

ifdef EXTRAFILES
	# Copy in any extra files.
	set -e; \
	for file in $(EXTRAFILES); do \
		mkdir -p $(TREE)/`dirname $$file`; \
		cp -a $$file $(TREE)/$$file; \
	done
endif

ifdef EXTRALIBS
	# Copy in any extra libs.
	set -e; \
	for file in $(EXTRALIBS); do \
		mkdir -p $(TREE)/`dirname $$file`; \
		cp -a $$file $(TREE)/$$file; \
	done
endif

	@touch $@


$(STAMPS)tree-$(targetstring)-stamp: $(STAMPS)tree-unpack-$(targetstring)-stamp
	# Create a dev tree.
	mkdir -p $(TREE)/dev
	# Always needed, in case devfs is not mounted on boot.
	# userdevfs uses userdevfs-dev.txt w/genext2fs
ifndef USERDEVFS
	mknod $(TREE)/dev/console c 5 1
	mknod $(TREE)/dev/null c 1 3
endif

ifdef EXTRADRIVERS
	# Unpack the udebs of additional driver disks, so mklibs runs on them too.
	mkdir -p $(EXTRADRIVERSDIR)
	mkdir -p $(EXTRADRIVERSDPKGDIR)/info $(EXTRADRIVERSDPKGDIR)/updates
	touch $(EXTRADRIVERSDPKGDIR)/status $(EXTRADRIVERSDPKGDIR)/available
	dpkg $(DPKG_UNPACK_OPTIONS) --root=$(EXTRADRIVERSDIR) --unpack \
		$(wildcard $(foreach dir,$(EXTRADRIVERS),$(dir)/*.udeb))
endif

	# Library reduction. Existing libs from udebs are put in the udeblibs
	# directory and mklibs is made to use those in preference to the
	# system libs.
	rm -rf $(TEMP)/udeblibs
	mkdir -p $(TEMP)/udeblibs
	-cp -a `find $(TREE)/lib -type f -name '*.so.*'` $(TEMP)/udeblibs
	mkdir -p $(TREE)/lib
	$(MKLIBS) -L $(TREE)/usr/lib -L $(TEMP)/udeblibs -v -d $(TREE)/lib --root=$(TREE) `find $(TEMP) -type f -perm +0111 -o -name '*.so' | grep -v udeblibs`
	rm -rf $(TEMP)/udeblibs

	# Add missing symlinks for libraries
	/sbin/ldconfig -n $(TREE)/lib $(TREE)/usr/lib

	# Remove any libraries that are present in both usr/lib and lib,
	# from lib. These were unnecessarily copied in by mklibs, and
	# we want to use the ones in usr/lib instead since they came 
	# from udebs. Only libdebconf has this problem so far.
	set -e; \
	for lib in `find $(TREE)/usr/lib/ -name "lib*" -type f -printf "%f\n" | cut -d . -f 1 | sort | uniq`; do \
		rm -f $(TREE)/lib/$$lib.*; \
	done

	# Reduce status file to contain only the elements we care about.
	egrep -i '^((Status|Provides|Depends|Package|Version|Description|installer-menu-item|Description-..):|$$)' \
		$(DPKGDIR)/status > $(DPKGDIR)/status.new
	mv $(DPKGDIR)/status.new $(DPKGDIR)/status

ifdef DROP_LANG
	# Remove languages from the templates.
	# Not ideal, but useful if you're very tight on space.
	set -e; \
	for FILE in $$(find $(TREE) -name "*.templates"); do \
		perl -e 'my $$status=0; my $$drop=shift; while (<>) { if (/^[A-Z]/ || /^$$/) { if (/^(Choices|Description)-($$drop)/) { $$status = 0 } else { $$status = 1 } } print if ($$status); }' ${DROP_LANG} < $$FILE > temp; \
		mv temp $$FILE; \
	done
endif

	# If the image has pcmcia, reduce the config file to list only
	# entries that there are modules on the image. This saves ~30k.
	# Disabled for now, as it doesn't pass enough modules to the script.
	#set -e; \
	#if [ -e $(TREE)/etc/pcmcia/config ]; then \
	#	./pcmcia-config-reduce.pl $(TREE)/etc/pcmcia/config \
	#		`if [ -d "$(EXTRADRIVERSDIR)" ]; then find $(EXTRADRIVERSDIR)/lib/modules -name \*.o -name \*.ko; fi` \
	#		`find $(TREE)/lib/modules/ -name \*.o -or -name \*.ko` > \
	#		$(TREE)/etc/pcmcia/config.reduced; \
	#	mv -f $(TREE)/etc/pcmcia/config.reduced $(TREE)/etc/pcmcia/config; \
	#fi

	# Strip all kernel modules, just in case they haven't already been
	set -e; \
	for module in `find $(TREE)/lib/modules/ -name '*.o' -name '*.ko'`; do \
	    strip -R .comment -R .note -g $$module; \
	done

	# Remove some unnecessary dpkg files.
	set -e; \
	for file in `find $(TREE)/var/lib/dpkg/info -name '*.md5sums' -o \
	    -name '*.postrm' -o -name '*.prerm' -o -name '*.preinst' -o \
	    -name '*.list'`; do \
		if echo $$file | grep -qv '\.list'; then \
			echo "** Removing unnecessary control file $$file"; \
		fi; \
		rm $$file; \
	done

	# Collect the used UTF-8 strings, to know which glyphs to include in
	# the font.
	cat graphic.utf needed-characters/?? > $(TEMP)/all.utf
ifdef EXTRADRIVERS
	if [ -n "`find $(EXTRADRIVERSDPKGDIR)/info/ -name \\*.templates`" ]; then \
		cat $(EXTRADRIVERSDPKGDIR)/info/*.templates >> $(TEMP)/all.utf; \
	fi
endif
	if [ -n "`find $(DPKGDIR)/info/ -name \\*.templates`" ]; then \
		cat $(DPKGDIR)/info/*.templates >> $(TEMP)/all.utf; \
	fi

ifdef EXTRADRIVERS
	# Remove additional driver disk contents now that we're done with
	# them.
	rm -rf $(EXTRADRIVERSDIR)
endif

	# Tree target ends here. Whew!
	@touch $@


#
# Acquire the necessary .udeb packages.
#

# Get the list of udebs to install.
# HACK Alert: pkg-lists/ is still sorted by TYPE instead of a dir hierarchy.
UDEBS = $(shell set -e; ./pkg-list $(TYPE) $(KERNEL_FLAVOUR) $(KERNELMAJOR) "$(SUBARCH)" $(KERNELIMAGEVERSION)) $(EXTRAS)

# Get all required udebs and put them in UDEBDIR.
$(STAMPS)get_udebs-$(targetstring)-stamp: sources.list.udeb
	dh_testroot
	@rm -f $@
	./get-packages udeb $(UDEBS)
	@touch $@

# Auto-generate a sources.list.type
sources.list.udeb:
	(set -e; \
	echo "# This file is automatically generated, edit $@.local instead."; \
	if [ "$(MIRROR)x" != "x" ]; then \
		echo "deb $(MIRROR) $(SUITE) main/debian-installer"; \
	else \
		grep '^deb[ \t]' $(SYSTEM_SOURCES_LIST) \
		|grep -v '\(non-US\|non-us.debian.org\|security.debian.org\)' \
		|grep '[ \t]main' \
		|awk '{print $$1 " " $$2}' \
		|sed "s,/* *$$, $(SUITE) main/debian-installer," \
		|sed "s,^deb file,deb copy," \
		|sort |uniq; \
	fi) > $@

sources.list.deb:
	(set -e; \
	echo "# This file is automatically generated, edit $@.local instead."; \
	if [ "$(MIRROR)x" != "x" ]; then \
		echo "deb $(MIRROR) $(SUITE) main"; \
	else \
		grep '^deb[ \t]' $(SYSTEM_SOURCES_LIST) \
		|grep -v '\(debian-non-US\|non-us.debian.org\|security.debian.org\)' \
		|grep '[ \t]main' \
		|awk '{print $$1 " " $$2}' \
		|sed "s,/* *$$, $(SUITE) main," \
		|sed "s,^deb file,deb copy," \
		|sort |uniq; \
	fi) > $@


#
# Font generation.
#
$(TREE)/unifont.bgf: $(TEMP)/all.utf
	# Use the UTF-8 locale in rootskel-locale. This target shouldn't
	# be called when it is not present anyway.
	# The locale must be generated after installing the package locales
	set -e; \
	CHARMAP=`LOCPATH=$(LOCALE_PATH) LC_ALL=C.UTF-8 locale charmap`; \
            if [ UTF-8 != "$$CHARMAP" ]; then \
	        echo "error: Trying to build unifont.bgf without rootskel-locale!"; \
	        exit 1; \
	    fi
	LOCPATH=$(LOCALE_PATH) LC_ALL=C.UTF-8 reduce-font /usr/src/unifont.bdf < $(TEMP)/all.utf > $(TEMP)/unifont.bdf
	# bdftobogl is part of package libbogl-dev
	bdftobogl -b $(TEMP)/unifont.bdf > $@.tmp
	mv $@.tmp $@


#
# Create the images for dest/. Those are the targets called from config.
#
# Create a compressed image of the root filesystem by way of genext2fs.
$(INITRD): $(TEMP_INITRD) $(TEMP_INITRD_LIST)
	install -m 644 -D $< $@
	install -m 644 -D $(TEMP_INITRD_LIST) $(INITRD_LIST)
	./update-manifest $@ $(MANIFEST-INITRD)
	./update-manifest $(INITRD_LIST) $(MANIFEST-INITRD_LIST)

$(TEMP_INITRD): $(STAMPS)tree-$(targetstring)-stamp
	# Only build the font if we have rootskel-locale
	if [ -d "$(LOCALE_PATH)/C.UTF-8" ] && [ -e /usr/src/unifont.bdf ]; then \
		$(submake) $(TREE)/unifont.bgf; \
	fi
	install -d $(TEMP)

	case $(INITRD_FS) in \
	ext2) \
		if [ "" != "$(USERDEVFS)" ]; then \
			echo $(USERDEVFS_SIZE) > $(TREE)/ramdisk_settings; \
			$(genext2fs-userdevfs) $(TEMP)/initrd; \
		else \
			$(genext2fs) $(TEMP)/initrd; \
		fi; \
		$(e2fsck) $(TEMP)/initrd || true;; \
	cramfs) \
		$(mkcramfs) $(TEMP)/initrd ;; \
	*) \
		echo "Unsupported filesystem type"; \
		exit 1 ;; \
	esac
	gzip -v9f $(TEMP)/initrd

$(TEMP_INITRD_LIST): $(TEMP_INITRD)

# raw kernel images
$(KERNEL): TEMP_REAL_KERNEL = $(TEMP)/$(shell echo ./$@ |sed 's,$(SOME_DEST)/$(EXTRANAME),,')
$(KERNEL):
	@$(MAKE) $(STAMPS)tree-unpack-$(targetstring)-stamp $(TEMP_REAL_KERNEL)
	install -m 644 -D $(TEMP_REAL_KERNEL) $@
	./update-manifest $@ $(MANIFEST-KERNEL)

# bootable images
$(BOOT): $(TEMP_BOOT)
	install -m 644 -D $(TEMP_BOOT)$(GZIPPED) $@
	./update-manifest $@ $(MANIFEST-BOOT)

$(TEMP_KERNEL): $(STAMPS)tree-unpack-$(targetstring)-stamp

$(TEMP_BOOT): $(TEMP_INITRD) $(TEMP_KERNEL) $(TEMP_BOOT_SCREENS) arch_boot

# non-bootable root images
$(ROOT): $(TEMP_ROOT)
	install -m 644 -D $(TEMP_ROOT)$(GZIPPED) $@
	./update-manifest $@ $(MANIFEST-ROOT)

$(TEMP_ROOT): $(TEMP_INITRD) arch_root

# miniature ISOs with only a boot image
$(MINIISO): $(TEMP_MINIISO)
	install -m 644 -D $(TEMP_MINIISO) $@
	./update-manifest $@ $(MANIFEST-MINIISO)

$(TEMP_MINIISO): $(TEMP_BOOT_SCREENS) arch_miniiso

# various kinds of information, for use on debian-cd isos.
$(DEBIAN_CD_INFO): $(TEMP_BOOT_SCREENS)
	(cd $(TEMP_BOOT_SCREENS); tar czf - .) > $@
	./update-manifest $@ $(MANIFEST-DEBIAN_CD_INFO)

# a tarball for pxe netbooting.
$(PXE_BOOT): $(TEMP_BOOT_SCREENS) $(TEMP_PXE_BOOT)
	(cd $(TEMP_PXE_BOOT); tar czf - .) > $@
	./update-manifest $@ $(MANIFEST-PXE_BOOT)

$(TEMP_BOOT_SCREENS): arch_boot_screens
$(TEMP_PXE_BOOT): arch_pxe_boot

$(MISC): TEMP_REAL_MISC = $(shell echo ./$@ |sed 's,$(SOME_DEST)/$(EXTRANAME),,')
$(MISC): 
	install -m 644 $(TEMP_REAL_MISC) $(SOME_DEST)/$(EXTRANAME)
	./update-manifest \
		$(SOME_DEST)/$(EXTRANAME)$(shell basename $(TEMP_REAL_MISC)) \
		$(MANIFEST-MISC)

# Other images, e.g. driver floppies. Those are simply handled as flavours
$(EXTRA): $(TEMP_EXTRA)
	install -m 644 -D $(TEMP_EXTRA)$(GZIPPED) $@
	./update-manifest $@ $(MANIFEST-EXTRA)

$(TEMP_EXTRA): $(STAMPS)extra-$(targetstring)-stamp
	install -d $(shell dirname $@)
	install -d $(TREE)
	set -e; case $(INITRD_FS) in \
	ext2) \
		if [ "$(IMAGE_SIZE)" = 1440 ]; then \
			genext2fs -d $(TREE) -b 1433 -r 0 $@; \
		else \
			genext2fs -d $(TREE) -b $(IMAGE_SIZE) -r 0 $@;\
		fi \
	;; \
	cramfs) \
		$(mkcramfs) $@ ;; \
	*) \
		echo "Unsupported filesystem type"; \
		exit 1 ;; \
	esac
	$(if $(GZIPPED),gzip -v9f $(TEMP_EXTRA))

$(STAMPS)extra-$(targetstring)-stamp: $(STAMPS)get_udebs-$(targetstring)-stamp
	@rm -f $@
	mkdir -p $(TREE)
	echo -n > $(TEMP)/diskusage.txt
	set -e; \
	for file in $(shell grep --no-filename -v ^\#  pkg-lists/$(TYPE)/common \
		`if [ -f pkg-lists/$(TYPE)/$(ARCH).cfg ]; then echo pkg-lists/$(TYPE)/$(ARCH).cfg; fi` \
		`if [ -f pkg-lists/$(TYPE)/$(ARCH)/$(SUBARCH).cfg ]; then echo pkg-lists/$(TYPE)/$(ARCH)/$(SUBARCH).cfg; fi` \
		| sed -e 's/^\(.*\)$${kernel:Version}\(.*\)$$/$(foreach VERSION,$(KERNELIMAGEVERSION),\1$(VERSION)\2\n)/g' ) ; do \
			cp $(UDEBDIR)/$$file* $(TREE) ; \
	done
	for udeb in $(TREE)/*.udeb ; do \
		if [ -f "$$udeb" ]; then \
			pkg=`basename $$udeb` ; \
			usedsize=`du -bs $$udeb | awk '{print $$1}'` ; \
			usedblocks=`du -s $$udeb | awk '{print $$1}'` ; \
			usedcount=1 ; \
			version=`dpkg-deb --info $$udeb | grep Version: | awk '{print $$2}'` ; \
			echo " $$usedsize B - $$usedblocks blocks - $$usedcount files used by pkg $$pkg (version $$version)" >>$(TEMP)/diskusage.txt;\
		fi; \
	done
	sort -n < $(TEMP)/diskusage.txt > $(TEMP)/diskusage.txt.new && \
		mv $(TEMP)/diskusage.txt.new $(TEMP)/diskusage.txt
	echo $(UDEBS) > $(TREE)/udeb_include
	./makelabel $(DISK_LABEL) $(BUILD_DATE) > $(TREE)/disk.lbl
	@touch $@

# Get a list of all the standard priority udebs, excluding kernel stuff.
pkg-lists/standard-udebs:
	./get-packages udeb
	grep-dctrl -FPriority -e 'required|standard|important' \
		-sPackage apt.udeb/state/lists/*_Packages* | \
		grep -v kernel-image | grep -v -- -modules | \
		cut -d " " -f 2 > $@
	# Add any local udebs to the list, skipping kernel stuff
	find localudebs/*.udeb -printf '%f\n' | grep -v kernel-image | grep -v -- -modules- | sed 's/_.*//' >> $@

# Get a list of all kernel modules matching the kernel version.
pkg-lists/kernel-module-udebs:
	./get-packages udeb
	grep-dctrl -P -e '.*-modules-$(KERNELVERSION)-$(KERNEL_FLAVOUR)' \
		-sPackage apt.udeb/state/lists/*_Packages* | \
		cut -d " " -f 2 > $@
	# Add any local kernel modules to the list.
	find localudebs/*-modules-$(KERNELVERSION)-$(KERNEL_FLAVOUR)_*.udeb -printf '%f\n' | sed 's/_.*//' >> $@
# The kernel version changes from build to build, so always regen the file.
.PHONY: pkg-lists/kernel-module-udebs

#
# Write (floppy) images
#
.PHONY: write_%
write_%:
	@install -d $(STAMPS)
	@$(submake) _write $(shell $(submake) $(subst write_,validate_,$@))

.PHONY: _write
_write: _build
	sudo dd if=$(TARGET) of=$(FLOPPYDEV) bs=$(FLOPPY_SIZE)k

# If you're paranoid (or things are mysteriously breaking..),
# you can check the floppy to make sure it wrote properly.
.PHONY: checkedwrite_%
checkedwrite_%:
	@install -d $(STAMPS)
	@$(submake) _checkedwrite $(shell $(submake) $(subst checkedwrite_,validate_,$@))

.PHONY: _checkedwrite
_checkedwrite: _write
	sudo cmp $(FLOPPYDEV) $(TARGET)


#
# generate statistics
# Suitable for a cron job, you'll only see the stats unless a build fails.
#
.PHONY: stats
stats:
	@echo "Image size stats"
	@echo
	$(submake) all_stats

# For manual invocation we provide a generic stats rule.
.PHONY: stats_%
stats_%:
	@$(submake) _stats $(shell $(submake) $(subst stats_,validate_,$@))

.PHONY: _stats
_stats: 
	@install -d $(BASE_TMP)
	@install -d $(STAMPS)
	@(set -e; $(submake) _build >$(BASE_TMP)log 2>&1 || \
	  (echo "build failure!"; cat $(BASE_TMP)log; false))
	@rm -f $(BASE_TMP)log
	@[ ! -f $(TEMP)/diskusage.txt ] || $(submake) general-stats

TOTAL_SZ = $(shell expr $(shell du -bs $(TREE) | cut -f 1) / 1024)
LIBS_SZ = $(shell [ -d $(TREE)/lib ] && du -hs --exclude=modules $(TREE)/lib |cut -f 1)
MODULES_SZ = $(shell [ -d $(TREE)/lib/modules ] && du -hs $(TREE)/lib/modules |cut -f 1)
ifeq ($(TEMP_INITRD),)
INITRD_SZ = 0
else
INITRD_SZ = $(shell expr \( $(shell [ -f $(TEMP_INITRD) ] && du -bs $(TEMP_INITRD) |cut -f 1) + 0 \) / 1024)
endif
ifeq ($(TEMP_KERNEL),)
KERNEL_SZ = 0
else
KERNEL_SZ = $(shell expr \( $(foreach kern,$(TEMP_KERNEL),$(shell [ -f $(kern) ] && du -bs $(kern) |cut -f 1)) + 0 \) / 1024)
endif
ifeq ($(TARGET),$(ROOT))
# image without a kernel
KERNEL_SZ = 0
endif
.PHONY: general-stats
general-stats:
	@echo k $(KERNEL_SZ) f $(FLOPPY_SIZE) i $(INITRD_SZ)
	@echo "System stats for $(targetstring)"
	@echo "-------------------------"
	@echo "Installed udebs: $(UDEBS)"
	@printf "Total system size: $(TOTAL_SZ)k"
ifneq ($(LIBS_SZ)$(MODULES_SZ),)
	@echo " ($(LIBS_SZ) libs, $(MODULES_SZ) kernel modules)"
else
	@echo
endif
	@echo "Initrd size: $(INITRD_SZ)k"
	@echo "Kernel size: $(KERNEL_SZ)k"
ifdef FLOPPY_SIZE
ifneq ($(INITRD_SZ),0)
	@echo "Free space: $(shell expr $(FLOPPY_SIZE) - $(KERNEL_SZ) - $(INITRD_SZ))k"
else
	@echo "Free space: $(shell expr $(FLOPPY_SIZE) - $(KERNEL_SZ) - $(TOTAL_SZ))k"
endif
endif
	@echo "Disk usage per package:"
	@sed 's/^/  /' < $(TEMP)/diskusage.txt

#
# demo target handling.
#
.PHONY: tree_mount
tree_mount: $(STAMPS)tree-$(targetstring)-stamp
	-@sudo /bin/mount -t proc proc $(TREE)/proc
ifdef USERDEVFS
	-@sudo chroot $(TREE) /usr/bin/update-dev
else
	-@sudo /bin/mount -t devfs dev $(TREE)/dev
endif

.PHONY: tree_umount
tree_umount:
ifndef USERDEVFS
	-@[ ! -c $(TREE)/dev/tty ] || sudo /bin/umount $(TREE)/dev
endif
	-@[ ! -L $(TREE)/proc/self ] || sudo /bin/umount $(TREE)/proc

# For manual invocation, we provide a demo rule. This starts the
# d-i demo from the tree in tmp.
.PHONY: demo_%
demo_%:
	@set -e; \
	export SUBARCH=; \
	export FLAVOUR=; \
	export MEDIUM=$(subst demo_,,$@); \
	$(submake) _demo

.PHONY: _demo
_demo: $(TARGET)
	@$(submake) tree_mount; \
	[ -f questions.dat ] && cp -f questions.dat $(TREE)/var/lib/cdebconf/ ; \
	sudo chroot $(TREE) bin/sh -c "export DEBCONF_DEBUG=5 ; /usr/bin/debconf-loadtemplate debian /var/lib/dpkg/info/*.templates; exec /usr/share/debconf/frontend /usr/bin/main-menu" ; \
	$(submake) tree_umount

.PHONY: shell_%
shell_%:
	@export SUBARCH=; \
	export FLAVOUR=; \
	export MEDIUM=$(subst shell_,,$@); \
	$(submake) _shell

.PHONY: _shell
_shell: $(TREE)
	@$(submake) tree_mount; \
	sudo chroot $(TREE) bin/sh; \
	$(submake) tree_umount

.PHONY: uml_%
uml_%:
	@set -e; \
	export SUBARCH=; \
	export FLAVOUR=; \
	export MEDIUM=$(subst uml_,,$@); \
	$(submake) _uml

.PHONY: _uml
_uml: $(TARGET)
	-linux initrd=$(INITRD) root=/dev/rd/0 ramdisk_size=8192 con=fd:0,fd:1 devfs=mount

.PHONY: qemu_%
qemu_%:
	@set -e; \
	export SUBARCH=; \
	export FLAVOUR=; \
	export MEDIUM=$(subst qemu_,,$@); \
	$(submake) _qemu $(shell $(submake) $(subst qemu_,validate_,$@))

.PHONY: _qemu
_qemu: $(TARGET)
	@case "$(MEDIA_TYPE)" in \
	floppy) \
		$(QEMU) -fda $(BOOT); \
	;; \
	*) \
		echo "Sorry, don't know how to handle media type '$(MEDIA_TYPE)'" >&2; \
		exit 1; \
	esac
