<!-- retain these comments for translator revision tracking -->
<!-- $Id: parameters.xml 11648 2004-03-22 00:37:46Z joeyh $ -->

 <sect1 id="boot-parms"><title>Boot Parameters</title>
<para>

Boot parameters are Linux kernel parameters which are generally used
to make sure that peripherals are dealt with properly.  For the most
part, the kernel can auto-detect information about your peripherals.
However, in some cases you'll have to help the kernel a bit.

</para><para>

If this is the first time you're booting the system, try the default
boot parameters (i.e., don't try setting arguments) and see if it works
correctly. It probably will.  If not, you can reboot later and look for
any special parameters that inform the system about your hardware.

</para><para>

Information on many boot parameters can be found in the 
<ulink url="http://www.tldp.org/HOWTO/BootPrompt-HOWTO.html"> Linux
BootPrompt HOWTO</ulink>, including tips for obscure hardware.  This
section contains only a sketch of the most salient parameters.  Some
common gotchas are included below in 
<xref linkend="boot-troubleshooting"/>.

</para><para>

When the kernel boots, a message 

<informalexample><screen>

Memory:<replaceable>avail</replaceable>k/<replaceable>total</replaceable>k available 

</screen></informalexample>

should be emitted early in the process.
<replaceable>total</replaceable> should match the total amount of RAM,
in kilobytes.  If this doesn't match the actual amount of RAM you have
installed, you need to use the
<userinput>mem=<replaceable>ram</replaceable></userinput> parameter,
where <replaceable>ram</replaceable> is set to the amount of memory,
suffixed with ``k'' for kilobytes, or ``m'' for megabytes.  For
example, both <userinput>mem=65536k</userinput> and
<userinput>mem=64m</userinput> mean 64MB of RAM.

</para><para>

If your monitor is only capable of black-and-white, use the
<userinput>mono</userinput> boot argument.  Otherwise, your
installation will use color, which is the default.

</para><para condition="supports-serial-console">

If you are booting with a serial console, generally the kernel will
autodetect this 
<phrase arch="mipsel">(although not on DECstations)</phrase>
If you have a videocard (framebuffer) and a keyboard also attached to
the computer which you wish to boot via serial console, you may have
to pass the
<userinput>console=<replaceable>device</replaceable></userinput>
argument to the kernel, where <replaceable>device</replaceable> is
your serial device, which is usually something like
<filename>ttyS0</filename>.

</para><para arch="sparc">

For &arch-title; the serial devices are <filename>ttya</filename> or
<filename>ttyb</filename>.
Alternatively, set the <envar>input-device</envar> and
<envar>output-device</envar> OpenPROM variables to
<filename>ttya</filename>.

</para>


  <sect2 id="installer-args"><title>Debian Installer Arguments</title>
<para>

The installation system recognizes a few boot arguments which may be
useful. 

</para>

<variablelist>
<varlistentry>
<term>DEBCONF_PRIORITY</term>
<listitem><para>

This parameter settings will set the highest priority of messages
to be displayed. 

</para><para>

The default installation uses <userinput>DEBCONF_PRIORITY=high</userinput>.
This means that both high and critical priority messages are shown, but medium
and low priority messages are skipped. 
If problems are encountered, the installer adjusts the priority as needed.

</para><para>

If you add <userinput>DEBCONF_PRIORITY=medium</userinput> as boot parameter, you
will be shown the installation menu and gain more control over the installation.
When <userinput>DEBCONF_PRIORITY=low</userinput> is used, all messages are shown
(this is equivalent to the <emphasis>expert</emphasis> boot method).
With <userinput>DEBCONF_PRIORITY=critical</userinput>, the installation system
will display only critical messages and try to do the right thing without fuss.

</para></listitem>
</varlistentry>


<varlistentry>
<term>DEBCONF_FRONTEND</term>
<listitem><para>

This boot parameter controls the type of user interface used for the
installer. The current possible parameter settings are:

<itemizedlist>
<listitem>
<para><userinput>DEBCONF_FRONTEND=noninteractive</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=text</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=newt</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=slang</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=ncurses</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=bogl</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=gtk</userinput></para>
</listitem><listitem>
<para><userinput>DEBCONF_FRONTEND=corba</userinput></para>
</listitem>
</itemizedlist>

The default front end is <userinput>DEBCONF_FRONTEND=newt</userinput>.
<userinput>DEBCONF_FRONTEND=text</userinput>
may be preferable for serial console installs.

</para></listitem>
</varlistentry>


<varlistentry>
<term>BOOT_DEBUG</term>
<listitem><para>

Passing this boot parameter will cause the boot to be more verbosely 
logged.

<variablelist>
<varlistentry>
<term><userinput>BOOT_DEBUG=0</userinput></term>
<listitem><para>This is the default.</para></listitem>
</varlistentry>

<varlistentry>
<term><userinput>BOOT_DEBUG=1</userinput></term>
<listitem><para>More verbose than usual.</para></listitem>
</varlistentry>

<varlistentry>
<term><userinput>BOOT_DEBUG=2</userinput></term>
<listitem><para>Lots of debugging information.</para></listitem>
</varlistentry>

<varlistentry>
<term><userinput>BOOT_DEBUG=3</userinput></term>
<listitem><para>

Shells are run at various points in the boot process to allow detailed
debugging. Exit the shell to continue the boot.

</para></listitem>
</varlistentry>
</variablelist>

</para></listitem>
</varlistentry>


<varlistentry>
<term>INSTALL_MEDIA_DEV</term>
<listitem><para>

The value of the parameter is the path to the device to load the
Debian installer from. For example,
<userinput>INSTALL_MEDIA_DEV=/dev/floppy/0</userinput>

</para><para>

The boot floppy, which normally scans all floppys and USB storage
devices it can to find the root floppy, can be overridden by this
parameter to only look at the one device.

</para></listitem>
</varlistentry>

<varlistentry>
<term>netcfg/use_dhcp</term>
<listitem><para>

If you are installing at the default priority, &d-i; will configure your
network interface using DHCP if a DHCP server is available on your network.
You can force &d-i; to allow static configuration by using the parameter
<userinput>netcfg/use_dhcp=false</userinput>.

</para></listitem>
</varlistentry>

<varlistentry>
<term>debian-installer/framebuffer</term>
<listitem><para>

Some architectures use the kernel framebuffer to offer installation in
a number of languages. If framebuffer causes a problem on your system
you can disable the feature by the parameter
<userinput>debian-installer/framebuffer=false</userinput>. Problem
symptoms are error messages about bterm or bogl, a blank screen, or
a freeze within a few minutes after starting the install.

</para><para arch="i386">

The <userinput>video=vga16:off</userinput> argument may also be used
to disable the framebuffer. Such problems have been reported on a Dell
Inspiron with Mobile Radeon card.

</para><para arch="m68k">

Such problems have been reported on the Amiga 1200 and SE/30.

</para><para arch="hppa">

Such problems have been reported on hppa.

</para></listitem>
</varlistentry>

<varlistentry arch="i386">
<term>debian-installer/probe/usb</term>
<listitem><para>

Using the parameter <userinput>debian-installer/probe/usb=false</userinput>
you can disable USB during installation. This option can be used if your
system freezes when USB is probed. We have also had a report where the
legacy keyboard emulation was disabled when USB was probed.

</para></listitem>
</varlistentry>

<varlistentry arch="i386">
<term>hw-detect/start_pcmcia</term>
<listitem><para>

If your system freezes during hardware detection of PCMCIA devices, you can
try disabling PCMCIA using <userinput>hw-detect/start_pcmcia=false</userinput>.
Note you will not be able to use any PCMCIA devices during installation.

</para></listitem>
</varlistentry>

</variablelist>
  </sect2>
 </sect1>

