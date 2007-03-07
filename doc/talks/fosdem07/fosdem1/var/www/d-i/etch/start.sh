#!/bin/sh
# start.sh preseed from http://hands.com/d-i/.../start.sh
#
# Copyright (c) 2005-2006 Hands.com Ltd
# distributed under the terms of the GNU GPL version 2 or (at your option) any later version
# see the file "COPYING" for details
#
set -e

. /usr/share/debconf/confmodule

preseed_fetch local_enabled_flag /tmp/local_enabled_flag
use_local=$(grep -v '^[[:space:]]*\(#\|$\)' /tmp/local_enabled_flag || true)
rm /tmp/local_enabled_flag
echo $use_local > /var/run/hands-off.local
if [ "true" = "$use_local" ]
then
  db_set preseed/run local/start.sh subclass.sh
else
  db_set preseed/run subclass.sh
fi

# Make sure that auto-install/classes exists, even if it wasn't on the cmdline
db_get auto-install/classes || {
  db_register debian-installer/dummy auto-install/classes
  db_subst auto-install/classes ID auto-install/classes
}

cat > /tmp/HandsOff-fn.sh <<'!EOF!'
# useful functions for preseeding
in_class() {
	echo ";$(debconf-get auto-install/classes);" | grep -q ";$1;"
}
classes() {
	echo "$(debconf-get auto-install/classes)" | sed -e 's/;/\n/g'
}
checkflag() {
	flagname=$1 ; shift
	if db_get $flagname && [ "$RET" ]
	then
		for i in "$@"; do
			echo ";$RET;" | grep -q ";$i;" && return 0
		done
	fi
	return 1
}
pause() {
	desc=$1 ; shift

	db_register hands-off/meta/text hands-off/pause/title
	db_subst hands-off/pause/title DESC "Conditional Debugging Pause"
	db_settitle hands-off/pause/title

	db_register hands-off/meta/text hands-off/pause
	db_subst hands-off/pause DESCRIPTION "$desc"
	db_input critical hands-off/pause
	db_unregister hands-off/pause
	db_unregister hands-off/pause/title
	db_go
}
!EOF!


# create templates for use in on-the-fly creation of dialogs
cat > /tmp/HandsOff.templates <<'!EOF!'
Template: hands-off/meta/text
Type: text
Description: ${DESC}
 ${DESCRIPTION}

Template: hands-off/meta/string
Type: string
Description: ${DESC}
 ${DESCRIPTION}

Template: hands-off/meta/boolean
Type: boolean
Description: ${DESC}
 ${DESCRIPTION}
!EOF!

debconf-loadtemplate hands-off /tmp/HandsOff.templates

