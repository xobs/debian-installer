#!/bin/sh

set -xe

mkdir test
cd test
mkdir -p var/lib/dpkg/info
touch var/lib/dpkg/status
../tools/udpkg/udpkg -i ../udebs/udpkg_*
usr/bin/udpkg -i ../udebs/cdebconf_*
usr/bin/udpkg -i ../udebs/main-menu_*
usr/bin/udpkg --unpack ../udebs/wget-retriever_*
usr/bin/udpkg --unpack ../udebs/anna_*
LD_LIBRARY_PATH=usr/lib usr/bin/debconf-loadtemplate \
	debian-installer var/lib/dpkg/info/*.templates
LD_LIBRARY_PATH=usr/lib PATH=usr/bin:$PATH \
	usr/share/debconf/frontend usr/bin/main-menu
