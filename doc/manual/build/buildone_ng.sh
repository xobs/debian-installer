#!/bin/sh

# Uncomment to debugging
#set -x

usage() {


	cat <<END

$0: Generate the Debian Installer Manual in several different formats

Usage: $0 [params]

[params] can be any combination of the following:

- 'debug' to make debug output appear and skip removing old files
- '--help' or 'help' to print this usage help
- a language name (see below)
- an architecture name (see below)
- a file format (see below)
- '-d <dir>' to produce output in the <dir>-directory

Example: $0 ru en i386 sparc pdf

Defaults: $default_language $default_format $default_arch

Available languages: 		$LANGUAGES
Available architectures: 	$ARCHS
Available formats:		$FORMATS

END

exit 0


}

create_ProfiledXML () {

    [ -x /usr/bin/xsltproc ] || return 9

    entities_path="$build_path/entities"
    source_path="$manual_path/$cur_lang"

    if [ ! "$official_build" ]; then
        unofficial_build="FIXME;unofficial-build"
    else
        unofficial_build=""
    fi

    . arch-options/$cur_arch

    # Join all architecture options into one big variable
    condition="$fdisk;$network;$boot;$smp;$other;$goodies;$unofficial_build;$status"

    # Write dynamic non-profilable entities into the file
    echo "<!-- arch- and lang-specific non-profilable entities -->" > $dynamic
    echo "<!ENTITY langext \".$cur_lang\">" >> $dynamic
    echo "<!ENTITY architecture \"$cur_arch\">" >> $dynamic
    echo "<!ENTITY kernelversion \"${kernelversion}\">" >> $dynamic
    echo "<!ENTITY altkernelversion \"${altkernelversion}\">" >> $dynamic
    sed "s:##SRCPATH##:$source_path:" templates/docstruct.ent >> $dynamic

    sed "s:##LANG##:$cur_lang:g" templates/install.xml.template | \
        sed "s:##TEMPDIR##:$tempdir:g" | \
        sed "s:##ENTPATH##:$entities_path:g" | \
        sed "s:##SRCPATH##:$source_path:" > $tempdir/install.$cur_lang.xml

    # Create the profiled xml file
    /usr/bin/xsltproc \
        --xinclude \
        --stringparam profile.arch "$archspec" \
        --stringparam profile.condition "$condition" \
        --output $tempdir/install.$cur_lang.profiled.xml \
        $stylesheet_profile \
        $tempdir/install.$cur_lang.xml
    RET=$?; [ $RET -ne 0 ] && return $RET

    return 0
}

create_HTML () {

    /usr/bin/xsltproc \
        --xinclude \
        --stringparam base.dir $tempdir/$cur_lang.$cur_arch.html/ \
        $stylesheet_html \
        $tempdir/install.${cur_lang}.profiled.xml

    RET=$?; [ $RET -ne 0 ] && return $RET

	output_files="$output_files $tempdir/$cur_lang.$cur_arch.html/"

    return 0
}

create_SingleHTML () {

    /usr/bin/xsltproc \
        --xinclude \
        --output $tempdir/install.$cur_lang.html \
        $stylesheet_html_single \
        $tempdir/install.${cur_lang}.profiled.xml

    RET=$?; [ $RET -ne 0 ] && return $RET

    mv $tempdir/install.$cur_lang.html $tempdir/install.$cur_lang.uncorr.html
    
	# Replace some unprintable characters
    sed "s:–:-:g        # n-dash
         s:—:--:g       # m-dash
         s:“:\&quot;:g  # different types of quotes
         s:”:\&quot;:g
         s:„:\&quot;:g
         s:…:...:g      # ellipsis
         s:™: (tm):g    # trademark" \
        $tempdir/install.$cur_lang.uncorr.html >$tempdir/install.$cur_lang.html
	
	rm $tempdir/install.$cur_lang.uncorr.html
	
#	output_files="$output_files $tempdir/install.$cur_lang.html"
    
	
}

create_Text () {

    [ -x /usr/bin/w3m ] || return 9

    # Set encoding for output file
    case "$cur_lang" in
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
            CHARSET=UTF-8
            ;;
    esac
    
    echo /usr/bin/w3m -dump $tempdir/install.$cur_lang.html \
        -o display_charset=$CHARSET \
        >$tempdir/install.$cur_lang.txt

    /usr/bin/w3m -dump $tempdir/install.$cur_lang.html \
        -o display_charset=$CHARSET \
        >$tempdir/install.$cur_lang.txt

    RET=$?; [ $RET -ne 0 ] && return $RET
    
    

    output_files="$output_files $tempdir/install.${cur_lang}.txt"

    return 0
}

create_JadeDVI () {
    
    [ -x /usr/bin/openjade ] || return 9
    [ -x /usr/bin/jadetex ] || return 9

    # Skip this step if the .dvi file already exists
    [ -f "$tempdir/install.${language}.dvi" ] && return

    echo "Info: creating temporary .tex file..."

    # And use openjade to generate a .tex file
    export SP_ENCODING="utf-8"
    /usr/bin/openjade -t tex \
        -b utf-8 \
        -o $tempdir/install.${language}.tex \
        -d $stylesheet_dsssl \
        -V tex-backend \
        $tempdir/install.${language}.profiled.xml
    RET=$?
    if [ $RET -eq 1 ] && [ -s $tempdir/install.${language}.tex ] ; then
        echo "Warning: recieved error $RET from 'openjade'; probably non-fatal so ignoring."
    else
        [ $RET -ne 0 ] && return $RET
    fi

    echo "Info: creating temporary .dvi file..."

    # Next we use jadetext to generate a .dvi file
    # This needs three passes to properly generate the index (page numbering)
    cd $tempdir
    for PASS in 1 2 3 ; do
        /usr/bin/jadetex install.${language}.tex >/dev/null
        RET=$?; [ $RET -ne 0 ] && break
    done
    cd ..
    [ $RET -ne 0 ] && return $RET

    return 0
}


create_newtex () {

    echo "Info: creating .tex file..."

    sed "s:##LANG##:$language:g" templates/driver.xsl.template > $tempdir/driver.xsl

    xsltproc \
	-o $tempdir/install.${language}.new.tex \
	$tempdir/driver.xsl \
	$tempdir/install.${language}.profiled.xml &> xsltproc.log # &> /dev/null

    RET=$?; [ $RET -ne 0 ] && break


}

create_newdvi () {


    [ -f "$tempdir/install.${language}.new.dvi" ] && return

    create_texnew
    
    echo "Info: creating temporary .dvi file..."

    cd $tempdir
    for PASS in 1 2 3 ; do
        /usr/bin/latex -interaction=batchmode install.${language}.new.tex
    done
    cd ..

}

create_pdfnew () {

    [ -x /usr/bin/dvipdf ] || return 9

    create_dvinew

    echo "Info: creating .pdf file..."

    cd $tempdir

    for PASS in 1 2 3 ; do
        /usr/bin/pdflatex -interaction=batchmode install.${language}.new.tex
    done

    cd ..
    mv $tempdir/install.${language}.new.pdf $destdir/

    return 0


}

create_newps () {


    create_dvinew

    echo "Info: creating .ps file..."

    /usr/bin/dvips -q $tempdir/install.${language}.new.dvi

    RET=$?; [ $RET -ne 0 ] && return $RET
    
    #echo "Move PS"
    
    #sleep 30
    
    
    mv install.${language}.new.ps $destdir/
    

}

create_pdf() {
    
    [ -x /usr/bin/dvipdf ] || return 9

    create_dvi
    RET=$?; [ $RET -ne 0 ] && return $RET

    echo "Info: creating .pdf file..."

    /usr/bin/dvipdf $tempdir/install.${language}.dvi
    RET=$?; [ $RET -ne 0 ] && return $RET
    mv install.${language}.pdf $destdir/

    return 0
}

create_ps() {
    
    [ -x /usr/bin/dvips ] || return 9

    create_dvi
    RET=$?; [ $RET -ne 0 ] && return $RET

    echo "Info: creating .ps file..."

    /usr/bin/dvips -q $tempdir/install.${language}.dvi
    RET=$?; [ $RET -ne 0 ] && return $RET
    mv install.${language}.ps $destdir/

    return 0
}

debug_echo () {
	if [ ! -z "$debug" ]; then
		echo "DEBUG: $1"
	fi
}

create_toolchain () {

	echo -n "$((($BUILD_NO-1)*100/$TOTAL_BUILDS))	 $cur_lang	$cur_arch	$cur_format	Docbook "
	for i in $1; do
		echo -n "-> $i "
		create_$i;
    	RET=$?; [ $RET -ne 0 ] && break
	done
	
}

create_file () {

	case $cur_format in
		singlehtml) create_toolchain "ProfiledXML SingleHTML" ;;
		html) create_toolchain "ProfiledXML HTML" ;;
		ps) create_toolchain "ProfiledXML JadeTeX JadeDVI PS" ;;
		pdf)  create_toolchain "ProfiledXML JadeTeX JadeDVI PS PDF" ;;
		dvi)  create_toolchain "ProfiledXML JadeTeX JadeDVI" ;;
		text)  create_toolchain "ProfiledXML SingleHTML Text" ;;
		psnew) create_toolchain "ProfiledXML LaTeX DVI newPS" ;;
		pdfnew) create_toolchain "ProfiledXML LaTeX DVI newPS newPDF" ;;
		tex) create_toolchain "ProfiledXML LaTeX" ;;
		dvinew) create_toolchain "ProfiledXML LaTeX DVI"  ;;
	esac

	return $RET
}

handle_errors () {

	RET=$?
	case $RET in
		0)
			BUILD_OK="$BUILD_OK $cur_lang/$cur_arch/$cur_format"
			;;
		1)
			BUILD_FAIL="$BUILD_FAIL $cur_lang/$cur_arch/$cur_format"
			ERROR="execution error"
			;;
		9)
			BUILD_FAIL="$BUILD_FAIL $cur_lang/$cur_arch/$cur_format"
			ERROR="missing build dependencies"
			;;
		*)
			BUILD_FAIL="$BUILD_FAIL $cur_lang/$cur_arch/$cur_format"
			ERROR="unknown, code $RET"
			;;
	esac
	if [ $RET -ne 0 ]; then
		echo "-- failed ($ERROR)!"
		return 1
	else
		echo "-- OK!"
		return 0
	fi
}

#################
# CONFIGURATION #
#################

# Define all possible languages, formats and archs.

LANGUAGES=`find .. -type d -maxdepth 1 -printf "%f \n" | grep -v "^\." | grep -v "historic" | grep -v "build"  | grep -v "scripts" | tr -d "\n" `
ARCHS=`find arch-options -type f -maxdepth 1 -printf "%f "`
FORMATS="html text pdf ps new.pdf new.ps"

# Defaults 

language=""
arch=""
format=""
default_language="en"
default_format="html"
default_arch="i386"
debug=""

# Paths

basedir="$(cd "$(dirname $0)"; pwd)"
manual_path="$(echo $basedir | sed "s:/build$::")"
build_path="$manual_path/build"
tempdir="build.tmp"
dynamic="${tempdir}/dynamic.ent"

stylesheet_dir="$build_path/stylesheets"
stylesheet_profile="$stylesheet_dir/style-profile.xsl"
stylesheet_html="$stylesheet_dir/style-html.xsl"
stylesheet_html_single="$stylesheet_dir/style-html-single.xsl"
stylesheet_fo="$stylesheet_dir/style-fo.xsl"
stylesheet_dsssl="$stylesheet_dir/style-print.dsl"


# Parse command line

while [ "$1" != "" ]
do
	case $LANGUAGES in
	*$1*) language="$language $1"
		;;
	*);;
	esac
	
	case $ARCHS in
	*$1*) arch="$arch $1"
		;;
	*);;
	esac
	
	case $FORMATS in
	*$1*) format="$format $1"
		;;
	*);;
	esac
	
	if [ "$1" == "--help" ]; then
		usage
	fi

	if [ "$1" == "debug" ]; then
		debug="yes"
	fi
	
	if [ "$1" == "-d" ]; then
		shift
		destdir="$1"
	fi
	
	shift
	
done

if [ -z "$language" ]; then
	language="$default_language"
fi

if [ -z "$format" ]; then
	format="$default_format"
fi

if [ -z "$arch" ]; then
	arch="$default_arch"
fi

debug_echo "Languages '$language'"
debug_echo "Formats '$format'"
debug_echo "Archs '$arch'"
	
# End parsing

cd $build_path

if [ -z "$destdir" ]; then
    destdir="build.out"
fi


debug_echo "Output into: $destdir"




## MAINLINE

# Clean old builds

if [ ! -z "$debug" ]; then
	rm -rf $tempdir
	rm -rf $destdir
fi

mkdir -p $tempdir
mkdir -p $destdir

# Create profiled XML. This is needed for all output formats.
#create_profiled
#RET=$?; [ $RET -ne 0 ] && exit 1

BUILD_OK=""
BUILD_FAIL=""
BUILD_NO="0"

output_files=""

TOTAL_BUILDS="$((`echo $language | wc -w`*`echo $arch | wc -w`*`echo $format | wc -w`))"

debug_echo "$TOTAL_BUILDS builds"

echo "% Done	Lang	Arch	Format	Status "

for cur_lang in $language; do

	for cur_arch in $arch; do

		for cur_format in $format ; do
			BUILD_NO=$(($BUILD_NO+1))
			create_file
			handle_errors
			mv $output_files "$destdir"
		done
	done
done

echo "100% done."

if [ ! -z "$debug" ]; then
	rm -r $tempdir
fi

# Evaluate the overall results
[ -n "$BUILD_SKIP" ] && echo "Info: The following formats were skipped:$BUILD_SKIP"
[ -z "$BUILD_FAIL" ] && exit 0            # Build successful for all formats
echo "Warning: The following formats failed to build:$BUILD_FAIL"
[ -n "$BUILD_OK" ] && exit 2              # Build failed for some formats
exit 1                                    # Build failed for all formats
