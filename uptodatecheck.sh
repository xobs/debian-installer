#! /bin/sh

# Check up-to-dateness of udebs in the archive

# First check if madison is available.
if ! which madison 2>&1 >/dev/null; then
	echo "Error: Unable to find the madison program.  Exiting."
	exit 1
fi

PACKAGES="anna main-menu retriever/cdrom retriever/choose-mirror retriever/file retriever/net rootskel libdebian-installer tools/autopartkit tools/ddetect tools/base-installer tools/grub-installer tools/lilo-installer tools/cdebconf tools/netcfg tools/partkit tools/prebaseconfig tools/cdrom-detect tools/selectdevice tools/udpkg utils tools/disk-detect"

cd ..

printf "%-25s %-15s %-15s %s\n" udeb "version in cvs" "version in sid" "needs upload"

for dir in $PACKAGES; do
    (
    	needsupload=no
        cd $dir
	dpkg-parsechangelog >/dev/null 2>&1 || (echo "Changelog for $dir broken; skipping" ; exit 1) || continue
        ver=$(dpkg-parsechangelog | grep ^Version | cut -d: -f 2)
        pkg=$(dpkg-parsechangelog | grep ^Source | cut -d: -f 2)
        archver=$(madison $pkg | grep unstable  | grep source | cut -d\| -f 2)
        if [ -z "$archver" ]; then 
            archver="n/a"
        fi
	if [ $ver != $archver ]; then
		needsupload=yes
	fi
        printf "%-25s %-15s %-15s %s\n" $pkg $ver $archver $needsupload
    )
done
