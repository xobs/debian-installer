#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 arch lang"
    exit 1
fi

arch=${1-i386}
language=${2-en}

## Function to check result of executed programs and exit on error
checkresult () {
    if [ ! "$1" = "0" ]; then
	exit $1
    fi
}

## First we define some paths to various xsl stylesheets
stylesheet_profile="/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/profiling/profile.xsl"
stylesheet_html="style-html.xsl"
stylesheet_fo="style-fo.xsl"

## Location to our tools
xsltprocessor=xsltproc
foprocessor=./fop/fop.sh

## Build preparation
dynamic="dynamic.ent"

# Official/unofficial builds.
if [ ! "$official_build" ]; then
	unofficial_build="FIXME;unofficial-build"
else
	unofficial_build=""
fi

## Now we have to setup correct profiling information for each architecture
case $arch in
    alpha)
        archspec="alpha;not-i386;not-s390;not-m68k;not-powerpc"
	kernelversion="2.4.26"
	
        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-nfsroot"
        boot="supports-floppy-boot"
        other="supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies=""
	;;
    arm)
        archspec="arm;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.25"
		
        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies="supports-lang-chooser"
	;;
    hppa)
        archspec="hppa;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.25"
	
        fdisk="cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies="supports-lang-chooser"
	;;
    i386)
        archspec="i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.26"
	
        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot;bootable-disk;bootable-usb"
        other="supports-pcmcia;supports-serial-console;rescue-needs-root-disk;workaround-bug-99926"
        smp="supports-smp-sometimes"
        goodies="supports-lang-chooser"
	;;
    ia64)
        archspec="ia64;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.26"
	
        fdisk="parted.txt;cfdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies="supports-lang-chooser"
	;;
    m68k)
        archspec="m68k;not-i386;not-s390;not-powerpc;not-alpha"
	kernelversion="2.2.26"
	
        fdisk="atari-fdisk.txt;mac-fdisk.txt;amiga-fdisk.txt;pmac-fdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot;bootable-disk"
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies="supports-lang-chooser"
	;;
    mips)
        archspec="mips;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.26"
	
        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies=""
	;;
    mipsel)
        archspec="mipsel;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.26"
	
        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies=""
	;;
    powerpc)
        archspec="powerpc;not-s390;not-m68k;not-i386;not-alpha"
	kernelversion="2.4.25"
	
        fdisk="mac-fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot;bootable-disk"
        other="supports-pcmcia;supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies="supports-lang-chooser"
	;;
    s390)
        archspec="s390;not-powerpc;not-m68k;not-i386;not-alpha"
	kernelversion="2.4.26"
	
        fdisk="fdasd.txt;dasdfmt.txt"
        network="supports-nfsroot"
        boot=""
        other="rescue-needs-root-disk"
        smp="defaults-smp"
        goodies=""
	;;
    sparc)
        archspec="sparc;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
	kernelversion="2.4.26"
	
        fdisk="fdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot"
        other="supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies=""
	;;
    *)
        echo "Unknown architecture ${arch}! Please elaborate."
	exit 1 ;;
esac

## Join all gathered info into one big variable
cond="$fdisk;$network;$boot;$smp;$other;$goodies;$unofficial_build"

## Write dynamic non-profilable entities into the file
echo "<!-- arch- and lang-specific non-profilable entities -->" > $dynamic
echo "<!ENTITY langext \".${language}\">" >> $dynamic
echo "<!ENTITY architecture \"${arch}\">" >> $dynamic
echo "<!ENTITY kernelversion \"${kernelversion}\">" >> $dynamic
echo "<!ENTITY altkernelversion \"${altkernelversion}\">" >> $dynamic

sed s/\"en/\"..\\/${language}/ docstruct.ent >>$dynamic


## And finally we use two pass encoding (needed for correct <xref>s)

## First we profile the document for our architecture...
$xsltprocessor --stringparam profile.arch "$archspec" \
               --stringparam profile.condition "$cond" \
               --output install.${language}.profiled.xml \
               $stylesheet_profile install.${language}.xml
checkresult $?

## ...then we convert it to the .html...
$xsltprocessor $stylesheet_html install.${language}.profiled.xml
checkresult $?

## ...and also to the .fo...
# $xsltprocessor --output install.${language}.fo \
#                $stylesheet_fo install.${language}.profiled.xml
# checkresult $?

## ...from which we can generate (little bit ugly) pdf/ps/txt.
# $foprocessor -fo install.${language}.fo -pdf install.${language}.pdf
# checkresult $?

