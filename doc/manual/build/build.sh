#!/bin/sh

languages="en" # cs fr pt_BR ja ...
architectures="alpha arm hppa i386 ia64 m68k mips mipsel powerpc s390 sparc"

destination="/tmp/manual"

[ -e "$destination" ] || mkdir "$destination"

for lang in $languages; do
    for arch in $architectures; do
	./buildone.sh "$arch" "$lang"
	mkdir "${destination}/${lang}.${arch}"
	mv *.html "${destination}/${lang}.${arch}"
	./clear.sh
    done
done
