#!/bin/sh

xsltproc=`which xsltproc`
stylesheet=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/html/chunk.xsl

if [ -n "$xsltproc" ] ; then
    if [ -e "$stylesheet" ]; then
	$xsltproc style-html.xsl internals.xml
    else
	echo stylesheet missing. Please install the docbook-xsl Debian package
	exit 1
    fi
else
    echo xsltproc not found. Please install the xsltproc Debian package
    exit 1
fi
