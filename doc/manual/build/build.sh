#!/bin/sh

if [ -z "$languages" ]; then
	# Please add languages only if they build properly.
	languages="en cs fr ja nl pt_BR de" # es
fi

if [ -z "$architectures" ]; then
	architectures="alpha arm hppa i386 ia64 m68k mips mipsel powerpc s390 sparc"
fi

if [ -z "$destination" ]; then
	destination="/tmp/manual"
fi

[ -e "$destination" ] || mkdir -p "$destination"

for lang in $languages; do
    for arch in $architectures; do
	if [ -n "$noarchdir" ]; then
		destsuffix="$lang"
	else
		destsuffix="${lang}.${arch}"
	fi
	./buildone.sh "$arch" "$lang"
	mkdir "$destination/$destsuffix"
	mv *.html "$destination/$destsuffix"
	./clear.sh
    done
done
