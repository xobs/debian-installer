#!/bin/sh

catalog=/usr/share/sgml/docbook/dtd/xml/4.2/catalog
xmldcl=/usr/share/sgml/declaration/xml.dcl
err=`tempfile`

if grep -q '^<!DOCTYPE' $1; then
  nsgmls -s -c $catalog $xmldcl $1 2> $err
else
  temp=`tempfile`
  topdir=`dirname $0`
  root=`sed -e '0,/<[a-z]/!d' $1 | sed -e '$!d' | sed -e 's/<\([a-z][a-zA-Z0-9]*\).*/\1/'`
  cat > $temp <<EOT
<!DOCTYPE $root PUBLIC "-//OASIS//DTD DocBook XML V4.2//EN" "docbookx.dtd"   
[<!ENTITY % entities       SYSTEM "entities.ent"> %entities;]>
EOT
  cat $1 >> $temp
  nsgmls -s -D$topdir -c $catalog $xmldcl $temp 2> $err
  rm -f $temp
fi

less $err