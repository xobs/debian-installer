#! /bin/sh

# Check up-to-dateness of udebs in the archive

# This can be a hostname or in the form user@hostname.
REMOTE=auric.debian.org

# ssh out to auric if necessary
if ! which madison 2>&1 >/dev/null; then
	MADISON="ssh $REMOTE madison"
else
	MADISON="madison"
fi

cd ..
top=$(pwd)

dirs=`find . 2>/dev/null |egrep 'debian/rules$'|rev|cut -d/ -f3-|rev|cut -d/ -f2-`

for dir in $dirs; do
	cd $top/$dir
	pkg=$(dpkg-parsechangelog | grep ^Source | cut -d\  -f 2)
	pkgs="$pkgs $pkg"
done

# Only run madison once, to make it fast remotely.
tmp=$(tempfile)
$MADISON $pkgs > $tmp

printf "%-25s %-15s %-15s %s\n" udeb "version in cvs" "version in sid" "needs upload"

(for dir in $dirs; do
    (
    	needsupload=no
        cd $top/$dir
	dpkg-parsechangelog >/dev/null 2>&1 || (echo "Changelog for $dir broken; skipping" ; exit 1) || continue
        ver=$(dpkg-parsechangelog | grep ^Version | cut -d\  -f 2)
        pkg=$(dpkg-parsechangelog | grep ^Source | cut -d\  -f 2)
        archver=$(egrep "(^| )$pkg " $tmp | grep unstable  | grep source | cut -d\| -f 2)
        if [ -z "$archver" ]; then 
            archver="n/a"
        fi
	if [ $ver != $archver ]; then
		needsupload=yes
	fi
        printf "%-25s %-15s %-15s %s\n" $pkg $ver $archver $needsupload
    )
done) | sort

rm -f $tmp
