#!/bin/sh

# If this is a Linux console, and it's a vga16 framebuffer, reset the
# palette, which has been set to the optimal colors for display of the
# boot logo.

if ! /usr/bin/tty | grep -q ttyS ; then
    # not a serial console.
    if [ -f /proc/fb ]; then
	# They have a framebuffer device.
	# That means we have work to do...
	echo -n "]R"
    fi
fi;
exit 0;
