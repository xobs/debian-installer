#!/usr/bin/perl -w
#
# $Id: mknettrom.pl,v 1.1 2006/02/01 05:01:24 ralphs Exp $
#
# Build an "Image Header" for NeTTrom 2.1.24 and beyond
# Works around the brain-damaged gzip marker problem.
#
# Copyright (C) 2006 Ralph Siemsen <ralphs@netwinder.org>
# Freely distributable under terms of the GPL.
#

my $kernel = shift or die "ERROR: please specify kernel filename\n";
my $kernel_size = -s $kernel or die "open $kernel failed: $!\n";

my $initrd = shift or die "ERROR: please specify initrd filename\n";
my $initrd_size = -s $initrd or die "open $initrd failed: $!\n";

# We also have pad the kernel and initrd to multiples of 4 bytes.
# Failure to observe this rule will cause subsequent sections to
# be corrupted when NeTTrom tries to copy them as longwords.
# (The famous ARM unaligned access shifts will occur)
my $kernel_padding = ($kernel_size % 4) ? (4 - $kernel_size % 4) : 0;
printf STDERR "Padding kernel from $kernel_size by $kernel_padding to ... ";
$kernel_size += $kernel_padding;
printf STDERR "$kernel_size\n";
my $initrd_padding = ($initrd_size % 4) ? (4 - $initrd_size % 4) : 0;
printf STDERR "Padding initrd from $initrd_size by $initrd_padding to ... ";
$initrd_size += $initrd_padding;
printf STDERR "$initrd_size\n";

#
# Constants that Nettrom looks for in the image header.
#
my $TAG_END	= 0xFFFF;  # Marker for no more tags 
my $TAG_BIOS	= 0xFFFE;  # NetWinder bios 
my $TAG_KERNEL	= 0xFFFD;  # ARM Linux ELF kernel file
my $TAG_IMAGE	= 0xFFFC;  # ARM Linux flat kernel file
my $TAG_ZIMAGE	= 0xFFFB;  # ARM Linux self-decompressing kernel file
my $TAG_INITRD	= 0xFFFA;  # initrd file system, optionally gzipped
my $TAG_START	= 0xFFF9;  # Marker (not used)

#
# Output always begins with this exact 32-byte long header
#
print "---- NetWinder Image Header ----";

#
# Now there can be up to 32 "tagged" sections, each consisting of:
# tag type, compressed size, uncompressed size, and start address.
# The latter two parameters are only important for TAG_INITRD.
# Always end with a TAG_END line.
# 
print pack "iiii", $TAG_ZIMAGE, $kernel_size, $kernel_size, 0;
print pack "iiii", $TAG_INITRD, $initrd_size, 0, 0x800000;
print pack "iiii", $TAG_END, 0, 0, 0;

#
# Finally, concatenate the kernel and initrd.
# The 16-byte section identifier is repeated before each section.
# Nettrom actually ignores these, so 16 zeros work just as well.
#
print pack "iiii", $TAG_ZIMAGE, $kernel_size, $kernel_size, 0;
system "cat $kernel";
printf "%s", "\0"x$kernel_padding;

print pack "iiii", $TAG_INITRD, $initrd_size, 0, 0x800000;
system "cat $initrd";
printf "%s", "\0"x$initrd_padding;

