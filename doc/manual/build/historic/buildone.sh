#!/bin/sh

if [ "$1" = "--help" ]; then
    echo "Usage: $0 arch lang"
    exit 0
fi

arch=${1:-i386}
language=${2:-en}

## Function to check result of executed programs and exit on error
checkresult () {
    if [ ! "$1" = "0" ]; then
	exit $1
    fi
}

## First we define some paths to various xsl stylesheets
#stylesheet_profile="/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/profiling/profile.xsl"
stylesheet_profile="style-profile.xsl"
stylesheet_html="style-html.xsl"
stylesheet_latex="style-latex.xsl"

## Location to our tools
xsltprocessor=xsltproc

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
        kernelversion="2.4.27"

        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies=""
	status="not-checked"
        ;;
    arm)
        archspec="arm;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies="supports-lang-chooser"
	status="not-checked"
        ;;
    hppa)
        archspec="hppa;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies="supports-lang-chooser"
	status="not-checked"
        ;;
    i386)
        archspec="i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot;bootable-disk;bootable-usb"
        other="supports-pcmcia;supports-serial-console;rescue-needs-root-disk;workaround-bug-99926"
        smp="supports-smp-sometimes"
        goodies="supports-lang-chooser"
	status="checked"
        ;;
    ia64)
        archspec="ia64;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="parted.txt;cfdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies="supports-lang-chooser"
	status="checked"
        ;;
    m68k)
        archspec="m68k;not-i386;not-s390;not-powerpc;not-alpha"
        kernelversion="2.2.25"

        fdisk="atari-fdisk.txt;mac-fdisk.txt;amiga-fdisk.txt;pmac-fdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot;bootable-disk"
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies="supports-lang-chooser"
	status="checked"
        ;;
    mips)
        archspec="mips;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies=""
	status="not-checked"
        ;;
    mipsel)
        archspec="mipsel;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot=""
        other="supports-serial-console;rescue-needs-root-disk"
        smp=""
        goodies=""
	status="not-checked"
        ;;
    powerpc)
        archspec="powerpc;not-s390;not-m68k;not-i386;not-alpha"
        kernelversion="2.6.8"

        fdisk="mac-fdisk.txt;cfdisk.txt"
        network="supports-tftp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot;bootable-disk"
        other="supports-pcmcia;supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies="supports-lang-chooser"
	status="not-checked"
        ;;
    s390)
        archspec="s390;not-powerpc;not-m68k;not-i386;not-alpha"
        kernelversion="2.4.27"
        
        fdisk="fdasd.txt;dasdfmt.txt"
        network="supports-nfsroot"
        boot=""
        other="rescue-needs-root-disk"
        smp="defaults-smp"
        goodies=""
	status="not-checked"
        ;;
    sparc)
        archspec="sparc;not-i386;not-s390;not-m68k;not-powerpc;not-alpha"
        kernelversion="2.4.27"

        fdisk="fdisk.txt"
        network="supports-tftp;supports-rarp;supports-dhcp;supports-bootp;supports-nfsroot"
        boot="supports-floppy-boot"
        other="supports-serial-console;rescue-needs-root-disk"
        smp="supports-smp"
        goodies=""
	status="not-checked"
        ;;
    *)
        echo "Unknown architecture ${arch}! Please elaborate."
        exit 1 ;;
esac

## Join all gathered info into one big variable
cond="$fdisk;$network;$boot;$smp;$other;$goodies;$unofficial_build;$status"

## Write dynamic non-profilable entities into the file
echo "<!-- arch- and lang-specific non-profilable entities -->" > $dynamic
echo "<!ENTITY langext \".${language}\">" >> $dynamic
echo "<!ENTITY architecture \"${arch}\">" >> $dynamic
echo "<!ENTITY kernelversion \"${kernelversion}\">" >> $dynamic
echo "<!ENTITY altkernelversion \"${altkernelversion}\">" >> $dynamic

sed s/\"en/\"..\\/${language}/ docstruct.ent >>$dynamic


## And finally we use two pass encoding (needed for correct <xref>s)

## First we profile the document for our architecture...
$xsltprocessor \
    --xinclude \
    --stringparam profile.arch "$archspec" \
    --stringparam profile.condition "$cond" \
    --output install.${language}.profiled.xml \
    $stylesheet_profile \
    install.${language}.xml
checkresult $?

## ...then we convert it to the .html...
$xsltprocessor \
    --xinclude \
    $stylesheet_html \
    install.${language}.profiled.xml
checkresult $?

## ...and optionally we can generate (little bit ugly) pdf/ps/txt.
# ./buildfop.sh pdf ${language}
# checkresult $?
