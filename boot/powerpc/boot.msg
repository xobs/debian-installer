Welcome to Debian GNU/Linux PowerPC (CODENAME)

In Addition to the default 'install' option, 
there is 'install-safe' which you should try if 
the system fails to boot at all (the typical
symptom is a white screen which doesn't go away).

************************************
If in doubt, just choose 'install', and if that 
doesn't work, try 'install-safe'.
************************************

You may add the desired debconf priority after
'install', for example

boot: install DEBCONF_PRIORITY=medium

The default priority is high; medium priority
will result in a more 'manual' menu-driven
installer experience.
