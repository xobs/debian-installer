#!/bin/sh
#  Extract messages from po files.
#  getallpo.sh (directory) | sort | uniq >> all-$(TYPE).utf

for FILE in `find $1 -name "*.po"`; do
  PREFILTER="cat"
  CHARSET=`grep "Content-Type: text/plain; charset=" $FILE | head -1 | sed "s/.*charset=//" | sed "s/\\\\\\n\"//"`
  if [ "$CHARSET" != "UTF-8" ]; then
    PREFILTER="iconv -f $CHARSET -t UTF-8"
  fi
  $PREFILTER $FILE | grep -v "^#" | sed "s/[a-zA-Z0-9 -~]//g"
done
