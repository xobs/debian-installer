#!/bin/sh

languages="en" # cs fr pt_BR ...

if [ -z "$architectures" ]; then
	architectures="alpha arm hppa i386 ia64 m68k mips mipsel powerpc s390 sparc"
fi

if [ -z "$destination" ]; then
	destination="/tmp/manual"
fi

if [ -z "$noarchdir" ]; then
	destsuffix="$lang"
else
	destsuffix="${lang}.${arch}"
fi

[ -e "$destination" ] || mkdir -p "$destination"

for lang in $languages; do
    for arch in $architectures; do
	./buildone.sh "$arch" "$lang"
	mkdir "$destination/$destsuffix"
	mv *.html "$destination/$destsuffix"
	./clear.sh
    done
done
