#!/bin/sh

if [ -z "$languages" ]; then
	# Please add languages only if they build properly.
	# languages="en cs es fr ja nl pt_BR" # ca da de el eu it ru

	# Buildlist of languages to be included on RC2 CD's
	languages="en cs es fr ja pt_BR"
fi

if [ -z "$architectures" ]; then
	architectures="alpha arm hppa i386 ia64 m68k mips mipsel powerpc s390 sparc"
fi

if [ -z "$destination" ]; then
	destination="/tmp/manual"
fi

if [ -z "$formats" ]; then
        #formats="html pdf ps txt"
        formats="html"
fi

[ -e "$destination" ] || mkdir -p "$destination"

if [ "$official_build" ]; then
	# Propagate this to children.
	export official_build
fi

for lang in $languages; do
    echo "Language: $lang";
    for arch in $architectures; do
	echo "Architecture: $arch"
	if [ -n "$noarchdir" ]; then
		destsuffix="$lang"
	else
		destsuffix="${lang}.${arch}"
	fi
	./buildone.sh "$arch" "$lang" "$formats"
	mkdir -p "$destination/$destsuffix"
	for format in $formats; do
	    if [ "$format" = html ]; then
		mv ./build.out/html/*.html "$destination/$destsuffix"
	    else
		mv ./build.out/install.$lang.$format "$destination/$destsuffix"
	    fi
	done
	./clear.sh
    done
done

