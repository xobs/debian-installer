#!/bin/sh

set -x

dest=udebs

root=fakeroot

dirs="anna main-menu retriever/choose-mirror retriever/file retriever/wget \
	tools/cdebconf tools/ddetect tools/netcfg tools/pcidetect \
	tools/udpkg"

for d in $dirs; do
  (cd $d;
   $root debian/rules clean;
   debian/rules build;
   $root debian/rules binary)
done

if [ -d $dest ]; then
   rm -rf $dest
fi

mkdir $dest

for d in `find . -name \*.udeb`; do
   mv $d $dest
done
