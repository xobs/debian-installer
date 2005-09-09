#!/bin/sh
for X in *po; do echo -n "$X: ";msgfmt --check --stat $X; done
rm -f messages.mo
