#!/bin/sh

#if [ "$#" -ne 2 ]; then
    #echo "Usage: $0 doctype lang"
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 lang"
    exit 1
fi

#doctype=${1-pdf}
#language=${2-en}
language=${1-en}

#case $doctype in
#    pdf|ps|txt)
#        ;;
#    *)
#        echo "Usage: $0 doctype lang"
#        echo "doctype is one of pdf (adobe acrobat), ps (postscript), txt (plain text)"
#        exit 1
#        ;;
#esac

## First we define some paths to various needed files
stylesheet_fo="/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/profiling/profile.xsl"
stylesheet_dsssl="/usr/share/sgml/docbook/stylesheet/dsssl/modular/print/docbook.dsl"
xml_decl="/usr/share/sgml/declaration/xml.dcl"

## Location to our tools
xsltprocessor=xsltproc

if [ -f install.${language}.profiled.xml ] ; then
	## ...and also to the .fo...
	$xsltprocessor --output install.${language}.fo \
               $stylesheet_fo install.${language}.profiled.xml

	export SP_ENCODING="xml"
	jade -t tex \
		-o install.${language}.profiled.jtex \
		-d $stylesheet_dsssl \
		$xml_decl \
		install.${language}.profiled.xml

	# Next we use jadetext to generate a .dvi file
	# This needs three passes to properly generate the index (pagenumbering)
	jadetex install.${language}.profiled.jtex
	jadetex install.${language}.profiled.jtex
	jadetex install.${language}.profiled.jtex
else
	echo "install.${language}.profiled.xml not found; please run buildone.sh first."
fi
