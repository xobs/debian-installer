#!/bin/sh

xsltproc=`which xsltproc`
lynx=`which lynx`
sgmltools=`which sgmltools`
w3m=`which w3m`

if [ -n "$xsltproc" ] ; then
    $xsltproc style-html.xsl i18n.xml
else
    echo xsltproc not found. Please install the xsltproc Debian package
    exit 1
fi

if [ -f index.html ] ; then
 mv index.html i18n.html
 if [ -n "$sgmltools" -a -n "$w3m" ] ; then
    # To be checked
    $sgmltools --backend=txt i18n.html >i18n.txt
 else
    if [ -n "$lynx" ] ; then
	$lynx -dump -nolist i18n.html >i18n.txt
    else
	echo sgmltools, w3m or lynx not found. 
        echo You need installing either sgmltools+w3m or lynx for
        echo being able to convert the HTML documentation to text
	exit 1
    fi
 fi
fi



