#!/bin/sh

# Copyright (C) 2006  Martin Michlmayr <tbm@cyrius.com>

# This code is covered by the GNU General Public License.

# See installer/doc/devel/hardware/arm/ss4000-e/firmware for an explanation
# of the upgrade process on devices based on FalconStor's firmware.

UPGRADE_PKG="$1"
UPGRADE_TYPE="$2"

case ${UPGRADE_TYPE} in
	0)
		echo "Upgrade type ${UPGRADE_TYPE} not supported by debian-installer"
		;;
	1 | 2 | 3)
		echo "Upgrading firmware..."
		echo "Flashing zImage..." > /dev/console
		/fs/writeflash -z /sysroot/images/vmlinuz-2.6.17-1-iop3xx > /dev/console
		echo "Flashing ramdisk.gz..." > /dev/console
		/fs/writeflash -r /sysroot/images/initrd.img-2.6.17-1-iop3xx > /dev/console
		echo "done"
		;;
	*)
		echo "Unknown upgrade type ${UPGRADE_TYPE}"
esac
rm -f ${UPGRADE_PKG}

