#!/bin/sh

if [ "$1" = "--help" ]; then
    echo "$0: Generate the Debian Installer Manual in several different formats"
    echo "Usage: $0 [arch] [lang] [format]"
    echo "[format] may consist of multiple formats provided they are quoted (e.g. \"html pdf\")"
    exit 1
fi

arch=${1:-i386}
language=${2:-en}
formats=${3:-html}

## Configuration
basedir="$(cd "$(dirname $0)"; pwd)"
manual_path="$(echo $basedir | sed "s:/build$::")"
build_path="$manual_path/build"
cd $build_path

stylesheet_dir="$build_path/stylesheets"
stylesheet_profile="$stylesheet_dir/style-profile.xsl"
stylesheet_html="$stylesheet_dir/style-html.xsl"
stylesheet_html_single="$stylesheet_dir/style-html-single.xsl"
stylesheet_fo="$stylesheet_dir/style-fo.xsl"
stylesheet_dsssl="$stylesheet_dir/style-print.dsl"

entities_path="$build_path/entities"
source_path="$manual_path/$language"

if [ -z $destination ]; then
    destination="build.out"
fi

tempdir="build.tmp"
dynamic="${tempdir}/dynamic.ent"

## Function to check result of executed programs and exit on error
checkresult () {
    if [ ! "$1" = "0" ]; then
        exit $1
    fi
}

create_profiled () {

    # Skip this step if the profiled .xml file already exists
    [ -f $tempdir/install.${language}.xml ] && return

    echo "Creating temporary profiled .xml file..."

    if [ ! "$official_build" ]; then
        unofficial_build="FIXME;unofficial-build"
    else
        unofficial_build=""
    fi

    # Now we source the profiling information for the selected architecture
    [ -f arch-options/${arch} ] || {
        echo "Error: unknown architecture $arch!"
        exit 1
    }
    . arch-options/$arch

    # Join all architecture options into one big variable
    condition="$fdisk;$network;$boot;$smp;$other;$goodies;$unofficial_build;$status"

    # Write dynamic non-profilable entities into the file
    echo "<!-- arch- and lang-specific non-profilable entities -->" > $dynamic
    echo "<!ENTITY langext \".${language}\">" >> $dynamic
    echo "<!ENTITY architecture \"${arch}\">" >> $dynamic
    echo "<!ENTITY kernelversion \"${kernelversion}\">" >> $dynamic
    echo "<!ENTITY altkernelversion \"${altkernelversion}\">" >> $dynamic

    sed "s:##SRCPATH##:$source_path:" templates/docstruct.ent >> $dynamic
    sed "s:##LANG##:$language:g" templates/install.xml.template | \
    sed "s:##TEMPDIR##:$tempdir:g" | \
    sed "s:##ENTPATH##:$entities_path:g" | \
    sed "s:##SRCPATH##:$source_path:" > $tempdir/install.${language}.xml

    # Create the profiled xml file
    /usr/bin/xsltproc \
        --xinclude \
        --stringparam profile.arch "$archspec" \
        --stringparam profile.condition "$condition" \
        --output $tempdir/install.${language}.profiled.xml \
        $stylesheet_profile \
        $tempdir/install.${language}.xml
    checkresult $?
}

create_html () {

    create_profiled
    
    echo "Creating .html files..."

    /usr/bin/xsltproc \
        --xinclude \
        --stringparam base.dir $destination/html/ \
        $stylesheet_html \
        $tempdir/install.${language}.profiled.xml
    checkresult $?
}

create_text () {

    create_profiled

    echo "Creating temporary .html file..."

    /usr/bin/xsltproc \
        --xinclude \
        --output $tempdir/install.${language}.html \
        $stylesheet_html_single \
        $tempdir/install.${language}.profiled.xml
    checkresult $?

    # Replace some unprintable characters
    cat $tempdir/install.${language}.html | \
        sed "s:\&#8211;:-:g        # n-dash
             s:\&#8212;:--:g       # m-dash
             s:\&#8220;:\&quot;:g  # different types of quotes
             s:\&#8221;:\&quot;:g
             s:\&#8222;:\&quot;:g
             s:«\|»:\&quot;:g      # quotes in Russian translation
             s:\&#8230;:...:g      # ellipsis
             s:\&#8482;: (tm):g    # trademark" \
        >$tempdir/install.${language}.corr.html
    checkresult $?

    echo "Creating .txt file..."

    # Set encoding for output file
    case $language in
        cs)
            CHARSET=ISO-8859-2
            ;;
        ja)
            CHARSET=EUC-JP
            ;;
        ru)
            CHARSET=KOI8-R
            ;;
        *)
            CHARSET=ISO-8859-1
            ;;
    esac
    
    w3m -dump $tempdir/install.${language}.corr.html \
        -o display_charset=$CHARSET \
        >$destination/install.${language}.txt
    checkresult $?
}

create_dvi () {
    
    # Skip this step if the .dvi file already exists
    [ -f $tempdir/install.${language}.dvi ] && return

    create_profiled
    
    echo "Creating temporary .tex file..."

    # And use openjade to generate a .tex file
    export SP_ENCODING="utf-8"
    /usr/bin/openjade -t tex \
        -b utf-8 \
        -o $tempdir/install.${language}.tex \
        -d $stylesheet_dsssl \
        -V tex-backend \
        $tempdir/install.${language}.profiled.xml
    RET=$?
    if [ $RET -eq 1 ] ; then
        echo "** Error $RET from 'openjade'; probably non-fatal so ignoring."
    else
        checkresult $RET
    fi

    echo "Creating temporary .dvi file..."

    # Next we use jadetext to generate a .dvi file
    # This needs three passes to properly generate the index (pagenumbering)
    cd $tempdir
    for PASS in 1 2 3 ; do
        /usr/bin/jadetex install.${language}.tex >/dev/null
        checkresult $?
    done
    cd ..
}

create_pdf() {
    
    create_dvi

    echo "Creating .pdf file..."

    /usr/bin/dvipdf $tempdir/install.${language}.dvi
    checkresult $?
    mv install.${language}.pdf $destination/
}

create_ps() {
    
    create_dvi

    echo "Creating .ps file..."

    /usr/bin/dvips -q $tempdir/install.${language}.dvi
    checkresult $?
    mv install.${language}.ps $destination/
}

## MAINLINE

# Clean old builds
rm -rf $tempdir
rm -rf $destination

[ -d $manual_path/$language ] || {
    echo "Error: unknown language $language!"
    exit 1
}

mkdir -p $tempdir
mkdir -p $destination

for format in $formats ; do
    case $format in

        html)  create_html;;
        ps)    create_ps;;
        pdf)   create_pdf;;
        txt)   create_text;;
        *) echo "Format $format unknown or not yet supported!";;

    esac
done

# Clean up
rm -r $tempdir

exit 0
