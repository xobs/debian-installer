#!/bin/sh -e

SOURCE="$1"
DEST="$2"
shift
shift
PACKAGES="$@"

rm "$DEST" || true
touch "$DEST"

get_depends() {
  grep-dctrl -X -P "$1" -s Depends -s Pre-depends "$DEST" \
  | sed "s/Depends: //g" | sed "s/Pre-depends: //g" \
  | sed "s/, /\n/g" | cut -d" " -f1
}

check() {
  while [ $# -gt 0 ]; do
    if [ x"`grep-dctrl -X -P "$1" "$DEST"`" = x ]; then
      echo $1
    fi
    shift
  done
}

add_package() {
  echo adding $1 >&2
  if [ x"`grep-dctrl -X -P "$1" "$DEST"`" = x ]; then
    grep-dctrl -X -P "$1" "$SOURCE" >>"$DEST"
    DEPENDS="`get_depends "$1"`"
    check $DEPENDS
  fi
}

while [ ! x"$PACKAGES" = x ]; do
  PACKAGE="`echo $PACKAGES | cut -d" " -f 1`"
  NEW=`add_package $PACKAGE`
  if [ ! x"$NEW" = x ]; then
    PACKAGES="$NEW `echo $PACKAGES | cut -s -d" " -f 2-`"
  else
    PACKAGES="`echo $PACKAGES | cut -s -d" " -f 2-`"
  fi
done
