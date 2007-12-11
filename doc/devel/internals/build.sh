#!/bin/sh

xsltproc=`which xsltproc`
lynx=`which lynx`
sgmltools=`which sgmltools`
w3m=`which w3m`
stylesheet=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/html/chunk.xsl

if [ -n "$xsltproc" ] ; then
    if [ -e "$stylesheet" ]; then
	$xsltproc style-html.xsl d-i_debconf6.xml
    else
	echo stylesheet missing. Please install the docbook-xsl Debian package
	exit 1
    fi
else
    echo xsltproc not found. Please install the xsltproc Debian package
    exit 1
fi

exit 0

if [ -f index.html ] ; then
 if [ -n "$sgmltools" -a -n "$w3m" ] ; then
    # To be checked
    $sgmltools --backend=txt index.html >d-i_debconf6.txt
 else
    if [ -n "$lynx" ] ; then
	$lynx -dump -nolist index.html >d-i_debconf6.txt
    else
	echo sgmltools, w3m or lynx not found. 
        echo You need installing either sgmltools+w3m or lynx for
        echo being able to convert the HTML documentation to text
	exit 1
    fi
 fi
fi
