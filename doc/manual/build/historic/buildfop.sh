#!/bin/sh

if [ "$1" = "--help" ]; then
    echo "Usage: $0 doctype lang"
    exit 0
fi

doctype=${1:-pdf}
language=${2:-en}

case $doctype in
    pdf|ps|txt)
        ;;
    *)
        echo "Usage: $0 doctype lang"
        echo "doctype is one of pdf (adobe acrobat), ps (postscript), txt (plain text)"
        exit 1
        ;;
esac

## First we define some paths to various xsl stylesheets
stylesheet_profile="/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/profiling/profile.xsl"
stylesheet_fo="style-fo.xsl"

## Location to our tools
xsltprocessor=xsltproc
foprocessor=/usr/bin/fop

if [ -f install.${language}.profiled.xml ] ; then
	## ...and also to the .fo...
	$xsltprocessor --output install.${language}.fo \
               $stylesheet_fo install.${language}.profiled.xml

	## ...from which we can generate (little bit ugly) pdf/ps/txt.
	$foprocessor -fo install.${language}.fo -${doctype} install.${language}.${doctype}
else
	echo "install.${language}.profiled.xml not found; please run buildone.sh first."
fi

