#!/bin/bash -e
# powerpc initrd inbuilder script.
# Sven Luther, MArch 2004
# This is free software under the GNU General Public License.

# May also be set in Makefile
arch=${architecture:-$(dpkg --print-architecture)}

# Print a usage message and exit if the argument count is wrong.
if [ $# != 6 ]; then
echo "Usage: $0 vmlinux System.map initrd.gz builddir destdir kvers" 1>&2
	cat 1>&2 << EOF

	vmlinux: the plain uncompressed powerpc/elf Linux kernel.
	System.map: uncompressed System.map.
	initrd.gz: a compressed disk image to load in ramdisk and mount as root.
	builddir: temporary directory where the kernel-build tree is unpacked to.
	destdir: destination directory for the kernel images with builtin initrd.
	kvers: version of the kernel to build
EOF

	exit -1
fi

# Set this to the location of the kernel
kernel=$1

# Set this to the path of the compressed System.map
sysmap=$2

# Set this to the path of the compressed initrd
initrd=$3

# Set this to the path of the temporary build directory
builddir=$4

# Set this to the path of the destination directory
destdir=$5

# Set this to the kernel version used.
kvers=$6

# Make sure the files are available, $sysmap can be /dev/null
for file in "$kernel" "$initrd"; do
	if [ ! -f $file ]; then
		echo "error: could not find $file"
		exit 1
	fi
done

# Make sure the directories are available
for file in "$builddir" "$destdir"; do
	if [ ! -d $file ]; then
		echo "error: $file inexistand or not a directory"
		exit 1
	fi
done

# Unpack the kernel source tree, if not present.
tar -C $builddir -xjf /usr/src/kernel-build-$kvers.tar.bz2

# Copy kernel, System.map and initrd to the build tree.
cp $kernel $builddir/kernel-build-$kvers
cp $sysmap $builddir/kernel-build-$kvers
cp $initrd $builddir/kernel-build-$kvers/arch/ppc/boot/images/ramdisk.image.gz

# Cleanup.
for i in `find $builddir/kernel-build-$kvers -name \*.o`; do touch $i; done
rm -f $builddir/kernel-build-$kvers/arch/ppc/boot/chrp/image.o
rm -f `find $builddir/kernel-build-$kvers -name .depend`

# Actual build of the kernels with builtin initrd.
make -C $builddir/kernel-build-$kvers/arch/ppc/boot		\
	TOPDIR=$builddir/kernel-build-$kvers OBJCOPY=objcopy	\
  	CONFIG_ALL_PPC=y CONFIG_VGA_CONSOLE=y			\
	CONFIG_SERIAL_CONSOLE=y zImage.initrd

# Copying build directories to destdir.
for subarch in chrp chrp-rs6k prep; do
	cp $builddir/kernel-build-$kvers/arch/ppc/boot/images/zImage.initrd.$subarch \
		$destdir/vmlinuz-$subarch.initrd
done

exit 0
