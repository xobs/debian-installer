# The type of system to build. Determines what udebs are unpacked into
# the system. See the .list files for various types. You may want to
# override this on the command line.
TYPE=net

# Build tree location. This can be overridden too.
TREE=builddir

# Directory apt uses for stuff.
APTDIR=apt

# Directory udebs are placed in.
UDEBDIR=udebs

# Local directory that is searched for udebs, to avoid downloading.
# (Or for udebs that are not yet available for download.)
LOCALUDEBDIR=localudebs

# All these options makes apt read ./sources.list, and
# use APTDIR for everything so it need not run as root.
APT_GET=apt-get --assume-yes \
	-o Dir::Etc::sourcelist=./sources.list \
	-o Dir::State=$(APTDIR)/state \
	-o Debug::NoLocking=true \
	-o Dir::Cache=$(APTDIR)/cache

UDEBS=$(shell grep --no-filename -v ^\# lists/base lists/$(TYPE))

build: tree reduce stats

demo:
	chroot $(TREE) bin/sh

clean:
	rm -rf $(TREE) $(APTDIR) $(UDEBDIR)

# Download all required udebs to UDEBDIR
get_udebs:
	mkdir -p $(APTDIR)/state/lists/partial
	mkdir -p $(APTDIR)/cache/archives/partial
	$(APT_GET) update
	# If there are local udebs, remove them from the list of things to
	# get. Then get all the udebs that are left to get.
	needed="$(UDEBS)"; \
	for file in `find $(LOCALUDEBDIR) -type f -printf %f 2>/dev/null`; do \
		package=`echo $$file | cut -d _ -f 1`; \
		needed=`echo $$needed | sed "s/$$package *//"`; \
	done; \
	echo $$needed; \
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
DPKGDIR=$(TREE)/var/lib/dpkg
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
	# Unpack the udebs with dpkg, ignoring dependancies.
	# (So you'd better get the deps right in your .list files!)
	# This command must run as root or fakeroot.
	dpkg --force-depends --root=$(TREE) --unpack $(UDEBDIR)/*.udeb
	# Clean up after dpkg.
	rm -rf $(DPKGDIR)/updates
	rm -f $(DPKGDIR)/available $(DPKGDIR)/available-old \
		$(DPKGDIR)/status-old $(DPKGDIR)/lock
	# TODO: configure some of the packages?
	# To save a little room, the status file could be reduced
	# to only contain those fields that udpkg knows about.

	# This is temporary; I have filed a bug asking ash-udeb to include
	# the link.
	ln -s ash builddir/bin/sh

# Library reduction.
reduce: tree
	mkdir -p $(TREE)/lib
	mklibs.sh -d $(TREE)/lib `find $(TREE) -type f -perm +0111`

stats:
	@echo
	@echo System stats
	@echo ------------
	@echo Installed udebs: $(UDEBS)
	@echo Total system size: $(shell du -h -s $(TREE) | cut -f 1)
# Add your interesting stats here.
	
