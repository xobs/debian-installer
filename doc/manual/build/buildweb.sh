#!/bin/sh

if [ -z "$languages" ]; then
    # Buildlist of languages to be included on the official website
    languages="en cs de es fr ja pt_BR ru"
fi

if [ -z "$architectures" ]; then
    architectures="alpha arm hppa i386 ia64 m68k mips mipsel powerpc s390 sparc"
fi

if [ -z "$destination" ]; then
	destination="/tmp/manual"
fi

if [ -z "$formats" ]; then
        formats="html pdf txt"
fi

[ -e "$destination" ] || mkdir -p "$destination"

export official_build="1"
export web_build="1"

for lang in $languages; do
    echo "Language: $lang";
    for arch in $architectures; do
        echo "Architecture: $arch"
        if [ -n "$noarchdir" ]; then
            destsuffix="$lang"
        else
            destsuffix="${arch}"
        fi
        ./buildone.sh "$arch" "$lang" "$formats"
        mkdir -p "$destination/$destsuffix"
        for format in $formats; do
            if [ "$format" = html ]; then
                mv ./build.out/html/* "$destination/$destsuffix"
            else
                mv ./build.out/install.$lang.$format "$destination/$destsuffix/install.$format.$lang"
            fi
        done
        ./clear.sh
    done
done

