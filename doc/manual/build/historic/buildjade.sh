#!/bin/sh

#doctype=${1:-pdf}
#language=${2:-en}
language=${1:-en}

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
#stylesheet_dsssl="/usr/share/sgml/docbook/stylesheet/dsssl/modular/print/docbook.dsl"
stylesheet_dsssl="style-print.dsl"
xml_decl="/usr/share/sgml/declaration/xml.dcl"

## Location to our tools
xsltprocessor=xsltproc

if [ -f install.${language}.profiled.xml ] ; then
	# And use openjade to convert generate a .tex file
	echo "Generating .tex..."
	export SP_ENCODING="utf-8"
	openjade -t tex \
		-b utf-8 \
		-o install.${language}.profiled.tex \
		-d $stylesheet_dsssl \
		install.${language}.profiled.xml

	# Next we use jadetext to generate a .dvi file
	# This needs three passes to properly generate the index (pagenumbering)
#	echo "Generating .dvi..."
	jadetex install.${language}.profiled.tex
	jadetex install.${language}.profiled.tex
	jadetex install.${language}.profiled.tex
	rm install.${language}.profiled.out
	rm install.${language}.profiled.aux

	# echo "Generating .pdf (using pdfjadetex)..."
	# pdfjadetex install.${language}.profiled.tex

	# echo "Generating .pdf (using dvipdf)..."
	dvipdf install.${language}.profiled.dvi
else
	echo "install.${language}.profiled.xml not found; please run buildone.sh first."
fi
