#!/bin/bash
# Boot Disk maker for TFTP prototcol.
# Eric Delaunay, February 1998.
# Ben Collins, March 2000,2002
# This is free software under the GNU General Public License.

# May also be set in Makefile
tmpdir=${tmpdir:-/var/tmp}
arch=${architecture:-$(dpkg --print-architecture)}

# Print a usage message and exit if the argument count is wrong.
if [ $# != 4 ]; then
echo "Usage: "$0" linux.bin sys_map.gz root-image tftpimage" 1>&2
	cat 1>&2 << EOF

	linux.bin: the Linux kernel (may be compressed).
	sys_map.gz: compressed System.map.
	root-image: a compressed disk image to load in ramdisk and mount as root.
	tftpimage: name of the image.
EOF

	exit -1
fi

# Set this to the location of the kernel
kernel=$1

# Set this to the name of the compressed System.map
sysmap=$2

# Set this to the location of the root filesystem image
rootimage=$3

# Set this to the name of the TFTP image
tftpimage=$4

# make sure the files are available
for file in "$kernel" "$rootimage"; do
	if [ ! -f $file ]; then
		echo "error: could not find $file"
		exit 1
	fi
done

tmp=`mktemp -d -p ${tmpdir} tftpboot.XXXXXX`


debug () {
    # either debug or the special verbose var can turn this on
    echo "D: " $* 1>&2 || true
}


if [ "$arch" = arm ] || [ "$arch" == i386 ] || [ "$arch" == mips ] || [ "$arch" == mipsel ]; then
	cp $kernel $tmp/image
	zcat < $sysmap > $tmp/sysmap
else
	echo "uncompressing kernel"
	zcat $kernel > $tmp/image
fi

echo "building tftp image in $tftpimage"
cp $tmp/image $tftpimage

# append rootimage to the kernel
if [ "$arch" = sparc ]; then
	elftoaout -o $tftpimage.tmp $tftpimage
	zcat $sysmap > $tmp/sysmap
	case $tftpimage in
		*sun4u*) piggyback=piggyback64 ;;
		*) piggyback=piggyback ;;
	esac
	# Piggyback appends the ramdisk to the a.out image in-place
	$piggyback $tftpimage.tmp $tmp/sysmap $rootimage
	mv $tftpimage.tmp $tftpimage
	rm -f $tmp/sysmap
elif [ "$arch" = arm ]; then
	if (grep -q "ARCH_CATS=y" $tmp/sysmap ); then
		catsboot $tftpimage.tmp $tftpimage $rootimage
		mv $tftpimage.tmp $tftpimage
	fi
	if (grep -q "ARCH_NETWINDER=y" $tmp/sysmap); then
		cat $rootimage >>$tftpimage
	fi
elif [ "$arch" = "mipsel" ]; then
		addinitrd $tftpimage $rootimage $tftpimage.tmp
		mv $tftpimage.tmp $tftpimage
elif [ "$arch" = "mips" ]; then
		/usr/sbin/tip22 $tftpimage $rootimage $tftpimage.tmp
		mv $tftpimage.tmp $tftpimage
fi

# cleanup
rm -fr $tmp

size=`ls -l $tftpimage | awk '{print $5}'` || true
rem=`expr \( 4 - $size % 4 \) % 4` || true

echo "padding $tftpimage by $rem bytes"
dd if=/dev/zero bs=1 count=$rem >> $tftpimage

echo "TFTP image is `ls -l $tftpimage` "

exit 0
