#! /bin/sh

# Check up-to-dateness of udebs in the archive

# First check if madison is available.
if madison ash > /dev/null 2>&1 ; then
	:
else
	echo "Error: Unable to find the madison program.  Exiting."
	exit 1
fi

PACKAGES="anna main-menu retriever/cdrom retriever/choose-mirror retriever/file retriever/wget rootskel libdebian-installer tools/autopartkit tools/ddetect tools/base-installer tools/grub-installer tools/kdetect tools/lilo-installer tools/lmod-detect-pci tools/cdebconf tools/netcfg tools/partkit tools/prebaseconfig tools/cdrom-detect tools/selectdevice tools/udpkg utils"

cd ..

printf "%-25s %-15s %-15s\n" udeb "version in cvs" "version in sid"

for dir in $PACKAGES; do
    (
        cd $dir
        ver=$(dpkg-parsechangelog | grep Version | cut -d: -f 2)
        pkg=$(dpkg-parsechangelog | grep Source | cut -d: -f 2)
        archver=$(madison $pkg | grep unstable  | grep source | cut -d\| -f 2)
        if [ -z "$archver" ]; then 
            archver="n/a"
        fi
        printf "%-25s %-15s %-15s\n" $pkg $ver $archver
    )
done
