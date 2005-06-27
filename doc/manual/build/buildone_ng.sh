#!/bin/sh

# Uncomment to debugging
#set -x

usage() {


	sed 's/\ \ /\ /g' <<END

Generate the Debian Installer Manual in several different formats

Usage: $0 [params]

[params] can be any combination of the following:

- 'debug' to make debug output appear and skip removing old files
- '--help' or 'help' to print this usage help
- a language name (see below)
- an architecture name (see below)
- a file format (see below)
- '-d <dir>' to produce output in the <dir>-directory
- 'official' to build the official version of the manual

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
	
	[ -f $tempdir/install.$cur_lang.profiled.xml ] && return
	
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
		$tempdir/install.$cur_lang.xml > /dev/null 2>&1
	RET=$?; [ $RET -ne 0 ] && return $RET

	return 0
}

create_HTML () {

	/usr/bin/xsltproc --xinclude \
		--stringparam base.dir	"$tempdir/$cur_lang.$cur_arch.html/" \
		$stylesheet_html \
		"$tempdir/install.$cur_lang.profiled.xml" > /dev/null 2>&1

	RET=$?; [ $RET -ne 0 ] && return $RET

	output_files="$output_files $tempdir/$cur_lang.$cur_arch.html/"

	return 0
}

create_SingleHTML () {

	if [ ! -f  $tempdir/install.$cur_lang.html ]; then
	
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

	fi

	output_files="$output_files $tempdir/install.$cur_lang.html"

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

create_JadeTeX () {
	
	[ -f  $tempdir/install.$cur_lang.tex ] && return
	
	
    [ -x /usr/bin/openjade ] || return 9
	
    # And use openjade to generate a .tex file
    export SP_ENCODING="utf-8"
    /usr/bin/openjade -t tex \
        -b utf-8 \
        -o $tempdir/install.${cur_lang}.tex \
        -d $stylesheet_dsssl \
        -V tex-backend \
        $tempdir/install.${cur_lang}.profiled.xml > /dev/null 2>&1
    RET=$?
    return $RET

}

create_JadeDVI () {
    
    [ -x /usr/bin/jadetex ] || return 9

    # Next we use jadetext to generate a .dvi file
    # This needs three passes to properly generate the index (page numbering)
    cd $tempdir
	echo -n "("
    for PASS in 1 2 3 ; do
		echo -n "$PASS"
        /usr/bin/jadetex -interaction=batchmode install.${cur_lang}.tex >/dev/null
#		RET=$?; [ $RET -ne 0 ] && break
		[ "$PASS" -lt 3 ] && echo -n "-"
    done
	echo -n ") "
    cd ..
    return $RET
}

create_LaTeX () {

	[ -f  $tempdir/install.$cur_lang.new.tex ] && return
	
    sed "s:##LANG##:$cur_lang:g" templates/driver.xsl.template > $tempdir/driver.xsl

	xsltproc \
		-o $tempdir/install.${cur_lang}.new.tex \
		$tempdir/driver.xsl \
		$tempdir/install.${cur_lang}.profiled.xml &> xsltproc.log
	
	RET=$?

#	Japanese is different :(

	if [ "$cur_lang" == "ja" ]; then
		cat $tempdir/install.${cur_lang}.new.tex | \
			sed 's/\\begin{document}/\\begin{document}\\begin{CJK*}\[dnp\]{JIS}{min}/g' | \
			sed 's/\\end{document}/\\end{CJK*}\\end{document}/g' \
			> $tempdir/install.${cur_lang}.new.tex.tmp
		mv $tempdir/install.${cur_lang}.new.tex.tmp $tempdir/install.${cur_lang}.new.tex
		recode -f UTF-8..EUC-JP $tempdir/install.${cur_lang}.new.tex
	fi
	
    output_files="$output_files $tempdir/install.${cur_lang}.new.tex"

	return $RET
	

}

create_DVI () {

	cd $tempdir
	echo -n "("
	for PASS in 1 2 3 ; do
		echo -n "$PASS"
		/usr/bin/latex -interaction=batchmode install.${cur_lang}.new.tex > /dev/null
#		RET=$?; [ $RET -ne 0 ] && break
		[ "$PASS" -lt 3 ] && echo -n "-"
	done
	echo -n ") "
	cd ..

}

create_newPDF () {

    cd $tempdir
	echo -n "("
    for PASS in 1 2 3 ; do
		echo -n "$PASS"
		/usr/bin/pdflatex -interaction=batchmode install.${cur_lang}.new.tex > /dev/null
#        RET=$?; [ $RET -ne 0 ] && break
		[ "$PASS" -lt 3 ] && echo -n "-"
    done
	echo -n ") "
    cd ..
	output_files="$output_files $tempdir/install.$cur_lang.new.pdf"
    return $RET

}

create_newPS () {


    /usr/bin/dvips -q $tempdir/install.${cur_lang}.new.dvi -o $tempdir/install.${cur_lang}.new.ps

    RET=$?; [ $RET -ne 0 ] && return $RET
    
	output_files="$output_files $tempdir/install.${cur_lang}.new.ps"

}

create_PDF() {
	
    cd $tempdir
	echo -n "("
    for PASS in 1 2 3 ; do
		echo -n "$PASS"
		/usr/bin/pdfjadetex -interaction=batchmode install.${cur_lang}.tex > /dev/null
        RET=$?; [ $RET -ne 0 ] && break
		[ "$PASS" -lt 3 ] && echo -n "-"
    done
	echo -n ") "
    cd ..
	output_files="$output_files $tempdir/install.${cur_lang}.pdf"
    return $RET
}

create_PS () {
    
    [ -x /usr/bin/dvips ] || return 9

    /usr/bin/dvips -q $tempdir/install.${cur_lang}.dvi -o $tempdir/install.${cur_lang}.ps
    RET=$?; [ $RET -ne 0 ] && return $RET
	
	output_files="$output_files $tempdir/install.${cur_lang}.ps"

    return 0
}

debug_echo () {
	if [ ! -z "$debug" ]; then
		echo "DEBUG: $1"
	fi
}

create_toolchain () {

	echo -n "$((($BUILD_NO-1)*100/$TOTAL_BUILDS))	$cur_lang	$cur_arch	$cur_format	Docbook "
	for i in $1; do
		echo -n "-> $i "
		create_$i;
    	RET=$?; [ $RET -ne 0 ] && break
	done
	
}

create_file () {

	case $cur_format in
		htmlone) create_toolchain "ProfiledXML SingleHTML" ;;
		html) create_toolchain "ProfiledXML HTML" ;;
		ps) create_toolchain "ProfiledXML JadeTeX JadeDVI PS" ;;
		pdf)  create_toolchain "ProfiledXML JadeTeX PDF" ;;
#		dvi)  create_toolchain "ProfiledXML JadeTeX JadeDVI" ;;
		text)  create_toolchain "ProfiledXML SingleHTML Text" ;;
		newps) create_toolchain "ProfiledXML LaTeX DVI newPS" ;;
		newpdf) create_toolchain "ProfiledXML LaTeX newPDF" ;;
		latex) create_toolchain "ProfiledXML LaTeX" ;;
#		dvinew) create_toolchain "ProfiledXML LaTeX DVI"  ;;
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

cleanup() {
	
if [ -z "$debug" ]; then
	rm -rf $tempdir
fi
	
}

#################
# CONFIGURATION #
#################

basedir="$(cd "$(dirname $0)"; pwd)"
manual_path="$(echo $basedir | sed "s:/build$::")"
build_path="$manual_path/build"

# Define all possible languages, formats and archs.

# Warning: it is necessary to keep spaces around each arch, language and
# format to make sure we don't get an arch 'ps' just because it's a
# substring of 'mipsel'

LANGUAGES=`find $basedir/.. -type d -maxdepth 1 -printf " %f \n" | grep -v "^\ \." | grep -v "build"  | grep -v "scripts" | grep -v "po" | sort | tr -d "\n"`
ARCHS=`find arch-options -type f -maxdepth 1 -printf " %f "`
FORMATS=" html text pdf ps newpdf newps  htmlone latex "

# Defaults 

language=""
arch=""
format=""
default_language="en"
default_format="html"
default_arch="i386"
debug=""

# Paths

tempdir="build.tmp"
dynamic="${tempdir}/dynamic.ent"

stylesheet_dir="$build_path/stylesheets"
stylesheet_profile="$stylesheet_dir/style-profile.xsl"
stylesheet_html="$stylesheet_dir/style-html.xsl"
stylesheet_html_single="$stylesheet_dir/style-html-single.xsl"
stylesheet_fo="$stylesheet_dir/style-fo.xsl"
stylesheet_dsssl="$stylesheet_dir/style-print.dsl"


######################
# Parse command line #
######################

while [ "$1" != "" ]; do
	found=""
	comp=" $1 "
	case $LANGUAGES in
	*$comp*) language="$1 $language"
		found="y"
		;;
	*);;
	esac
	
	case $ARCHS in
	*$comp*) arch="$1 $arch"
		found="y"
		;;
	*);;
	esac
	
	case $FORMATS in
	*$comp*) format="$1 $format"
		found="y"
		;;
	*);;
	esac
	
	if [ "$comp" == " --help " -o "$comp" == " help " ]; then
		usage
		found="y"
	fi

	if [ "$comp" == " debug " ]; then
		debug="yes"
		found="y"
	fi
	
	if [ "$comp" == " -d " ]; then
		shift
		destdir="$1"
		found="y"
	fi
	
	if [ "$comp" == " official " ]; then
		official_build="yes"	
		found="y"
	fi
	
	if [ -z "$found" ]; then
		echo "Option '$1' unknown or unsupported. Ignoring."
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


debug_echo "Output directory '$destdir'"



############
# MAINLINE #
############

# Clean old builds

#cleanup

#mkdir -p $tempdir

if [ ! -d "$destdir" ]; then 
	mkdir -p $destdir
fi

BUILD_OK=""
BUILD_FAIL=""
BUILD_NO="0"

output_files=""

TOTAL_BUILDS="$((`echo $language | wc -w`*`echo $arch | wc -w`*`echo $format | wc -w`))"

debug_echo "$TOTAL_BUILDS builds"

echo "------	----	----	------	------"
echo "% Done	Lang	Arch	Format	Status"
echo "------	----	----	------	------"

for cur_lang in $language; do
	for cur_arch in $arch; do
		cleanup && mkdir -p $tempdir
		for cur_format in $format ; do
			BUILD_NO=$(($BUILD_NO+1))
			create_file
			handle_errors 
			debug_echo "Output files '$output_files'"
			for i in $output_files; do
				output="$i"
			done
			mv "$output" "$destdir"
			output_files=""
		done
	done
done

echo "100% done."

cleanup

# Evaluate the overall results
[ -z "$BUILD_FAIL" ] && exit 0            # Build successful for all formats
echo "Warning: The following formats failed to build:$BUILD_FAIL"
[ -n "$BUILD_OK" ] && exit 2              # Build failed for some formats
exit 1                                    # Build failed for all formats

#######
# END #
#######
