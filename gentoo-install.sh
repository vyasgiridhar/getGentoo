#!/bin/sh

# Copyright (c) 2012, Michael Mol <mikemol@gmail.com>
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.

# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

################################################################################
#                                                                              #
#                              Configuration Variables                         #
#                                                                              #
################################################################################

# The script assumes the /boot and /home partitions already exist, are
# formatted, and may be mounted by specifying the filesystems' UUID.
# It also presumes that there's an HTTP proxy server available.

# This is all very rough at the moment, and it's strictly a "works for my
# systems, on mt network" thing. Hopefully things improve and are generalized.
# Patches very welcome.
#Mirror for portage snapshot and stage3 tarball
MIRROR=http://ftp.swin.edu.au/

#Rsync mirror
SYNC=rsync://rsync.cn.gentoo.org/gentoo-portage/

#Mirror base path
MIRROR_BASE_PATH=gentoo/

#stage 3 relative path
STAGE_PATH=releases/amd64/autobuilds/current-stage3-amd64/

#portage snapshot relative path
PORTAGE_PATH=snapshots/

#Stage3 tarball
STAGE_BALL=stage3-amd64-20170202.tar.bz2

PORTAGE_SNAPSHOT=portage-20170130.tar.xz

#Root filesystem device
ROOTDEV=/dev/sda3

ETC_CONFD_HOSTNAME="boombox"

ETC_TIMEZONE="Asia/Kolkata"

KERNEL_SOURCES="sys-kernel/gentoo-sources"

#make.conf

read -r -d '' MAKE_CONF <<'EOF'
CFLAGS="-O2 -pipe -march=native -ggdb"
CXXFLAGS="${CFLAGS}"

SYS_CPU_TGT="6"

MAKEOPTS="--jobs --load=${SYS_CPU_TGT}"
EMERGE_DEFAULT_OPTS="--jobs --load-average=${SYS_CPU_TGT} --verbose --tree --keep-going --with-bdeps=y"
FEATURES="splitdebug"
LINGUAS="en"

SYS_USE_CPU="mmx sse sse2 sse3 ssse3 openmp opencl posix nptl multilib smp lapack"
SYS_USE_LANG="perl python"
SYS_USE_TOOLKITS="gtk"
SYS_USE_GAPI="gd sdl ncurses xcb opengl v4l vdpau xv X dri"
SYS_USE_AAPI="openal alsa"
SYS_USE_OTHER="acl alsa cdr crypt cups dvd dvdr firefox gmp iconv nsplugin offensive pcre pda rss spell taglib truetype videos vim-syntax xattr xcomposite xft xinerama xml fontconfig qt3support phonon"
SYS_USE_COMPRESSION="bzip2 gzip lzma lzo szip zlib"
SYS_USE_MEDIA_GFX="imagemagick jpeg jpeg2k openexr png raw svg tiff wmf mng"
SYS_USE_MEDIA_AUDIO="aac cdda flac gsm lame mad mikmod shorten speex timidity vorbis mp3 midi"
SYS_USE_MEDIA_VIDEO="css dv ffmpeg theora x264 xvid"
SYS_USE_MEDIA_CONTAINERS="matroska mms mp3 mp4 mpeg ogg pdf vcd"
SYS_USE_MEDIA="${SYS_USE_MEDIA_GFX} ${SYS_USE_MEDIA_AUDIO} ${SYS_USE_MEDIA_VIDEO} ${SYS_USE_MEDIA_CONTAINERS} sound cddb encode exif gimp libsamplerate mtp ppds sndfile sox wavpack xmp latex"

SYS_USE_NET="avahi curl ftp geoip gnutls ipv6 libwww rdesktop samba sockets ssl tcpd vnc"
SYS_USE_PLATFORM="acpi dbus fam hddtemp ieee1394 joystick libnotify lm_sensors pam readline sharedmem syslog sysvipc threads udev unicode usb"

SYS_USE_DONOTWANT="-pulseaudio -oss -berkdb -gdbm"

USE="${SYS_USE_CPU} cxx lm_sensors java dbus doc audit bash-completion branding -gnome -kde -minimal -qt4 dbus jpeg lock session startup-notification thunar udev X" ${SYS_USE_LANG} ${SYS_USE_TOOLKITS} ${SYS_USE_GAPI} ${SYS_USE_AAPI} ${SYS_USE_OTHER} ${SYS_USE_MEDIA} ${SYS_USE_COMPRESSION} ${SYS_USE_NET} ${SYS_USE_PLATFORM} ${SYS_USE_DONOTWANT}"

GENTOO_MIRRORS="http://chi-10g-1-mirror.fastsoft.net/pub/linux/gentoo/gentoo-distfiles/ http://mirrors.cs.wmich.edu/gentoo http://gentoo.mirrors.tds.net/gentoo"

VIDEO_CARDS="nvidia"
INPUT_DEVICES="evdev"
ALSA_CARDS=""

#PORTAGE_BINHOST="http://binhost.ossdl.de/x86_64-pc-linux-gnu/"


CHOST="x86_64-pc-linux-gnu"
EOF

logger "Gentoo install: Grabbing release and portage tarballs"

ROOTPATH="$MIRROR$MIRROR_BASE_PATH"

STAGEFILEPATH="$ROOTPATH$STAGE_PATH$STAGE_BALL"
if [[ ! -f $STAGE_BALL ]]; then
    wget "$STAGEFILEPATH"
fi
unset STAGEFILEPATH

PORTAGEFILEPATH="$ROOTPATH$PORTAGE_PATH$PORTAGE_SNAPSHOT"
if [[ ! -f $PORTAGE_SNAPSHOT ]]; then
    wget "$PORTAGEFILEPATH"
fi
unset PORTAGEFILEPATH

unset ROOTPATH

logger "Gentoo install: Creating the filesystem"

#Create the filesystem
mkfs.ext4 -F "$ROOTDEV"

logger "Gentoo install: Extracting the root filesystem's UUID."

logger "Gentoo install: Mounting the filesystem"

# mount the root filesystem. We're going to play fast and loose with integrity,
# but it'll be OK as long as things don't crash before the script finishes. And
# if they do, we just run the script again.
mount "$ROOTDEV" -o nobarrier,max_batch_time=100000,data=writeback /mnt/gentoo

# Here, we deviate from the handbook; we'll mount /boot once we're chrooted.
# Instead, we go ahead and unpack our tarballs.

logger "Gentoo Install: Unpacking the stage tarball"

tar xjpf "$STAGE_BALL" -C /mnt/gentoo

logger "Gentoo install: Unpacking the portage snapshot."

tar xjpf "$PORTAGE_SNAPSHOT" -C /mnt/gentoo/usr


# Another deviation. Rather than assemble make.conf the Handbook way, we'll
# use a lump make.conf I already use.
logger "Gentoo install: Unpacking make.conf."

echo "$MAKE_CONF" > /mnt/gentoo/etc/make.conf

logger "Gentoo install: Writing timezone configuration"
echo "$ETC_TIMEZONE" > /mnt/gentoo/etc/timezone

cp "/mnt/gentoo/usr/share/zoneinfo/$ETC_TIMEZONE" /mnt/gentoo/etc/localtime

logger "Gentoo install: Adding rsync mirror"
echo "SYNC=$SYNC" >> /mnt/gentoo/etc/make.conf

logger "Gentoo install: Copying autodiscovered DNS details"

cp -L /etc/resolv.conf /mnt/gentoo/etc/resolv.conf

logger "Gentoo install: Mounting dev, proc, etc in target environment"

mount -t proc proc/ /mnt/gentoo/proc
if [[ $? -ne 0 ]]; then exit 1; fi
mount --rbind /dev /mnt/gentoo/dev/
if [[ $? -ne 0 ]]; then exit 1; fi

# And that's everything we do *outside* the chroot.
# we still want automation inside the chroot. So we build a second script to
# run in there.

read -r -d '' INNER_SCRIPT <<'INNERSCRIPT'

env-update
source /etc/profile
export PS1="(chroot) $PS1" # Not that the user will see this.

# Is there any reason the handbook specifies anything but emerges to be done
# _after_ the chroot?

# Extract data passed to us from the pre-chroot script.
FS_ROOT_UUID="$1"
FS_BOOT_UUID="$2"
FS_SWAP_UUID="$3"
FS_HOME_UUID="$4"
ETC_CONFD_HOSTNAME="$5"
ETC_CONFD_NET_FILE_CONTENT="$6"
http_proxy="$7"
KERNEL_SOURCES="$8"

script_fail() {
    logger "Gentoo install: Failing out"
    umount -l /dev
    umount -l /proc
    exit 1
}

script_check_fail() {
    if [[ $? -ne 0 ]]; then
        script_fail;
    else
       echo "Gentoo install: Cmd Succeeded"
    fi
}

script_em_sync() {
    logger "Syncing portage"
    emerge --sync
    script_check_fail
}

script_env_update() {
    logger "Gentoo install: Updating environment"
    env-update
    script_check_fail
    logger "Gentoo install: sourcing environment"
    source /etc/profile
}

script_write_fstab() {
    logger "Gentoo install: Writing fstab"
    # Clear out what's already there, first.
    echo "" > /etc/fstab

    echo "/dev/sda3\t/\text4\tdefaults\t0\t1" >> /etc/fstab
}

script_conf_hostname() {
    logger "Gentoo install: setting hostname"
    # Set the system hostname
    echo "hostname=\"$ETC_CONFD_HOSTNAME\"" > /etc/conf.d/hostname
}

script_conf_net() {
    logger "Configuring network"
    # Write the etc/conf.d/net file.
    echo "$ETC_CONFD_NET_FILE_CONTENT" > /etc/conf.d/net
}

script_conf_locale_gen_write() {
    logger "Writing and generating locales"
    # Clear out initial file.
    echo '' > /etc/locales.gen

    echo "en_US ISO-8859-1" >> /etc/locales.gen
    echo "en_US.UTF-8 UTF-8" >> /etc/locales.gen
}

script_conf_locales_select() {
    logger "Configuring environment locales"
    echo '' > /etc/env.d/02locale
    echo 'LANG="en_US.UTF-8"' >> /etc/env.d/02locale
    echo 'LC_COLLATE="C"' >> /etc/env.d/02locale
}

script_conf_locales() {
    script_conf_locales_write
    locale-gen
    script_check_fail

    script_conf_locales_select
    script_env_update
}

script_emerge_post() {
    logger "Gentoo install: beginning script_emerge_post."

    # It's possible for some critical stuff to have been changed, and these
    # commands _should_ be harmless if run when not needed. And since this
    # is a largely unattended script, this shouldn't be wasting much time.

    logger "Gentoo install: hash -r"
    hash -r
    script_env_update

    # These commands _may_ be harmful if run at the wrong time...but I've
    # tried to order them in a minimal-risk fashion.

    # Clean up anything which got broken by the emerge.
    hash python-updater 2> /dev/null
    if [[ $? -eq 0 ]]; then
        logger "Gentoo install: python updater"
        python-updater
    fi

    hash python-updater 2> /dev/null
    if [[ $? -eq 0 ]]; then
        logger "Gentoo install: perl updater"
        perl-cleaner --reallyall
    fi

    logger "Gentoo install: revdep-rebuild"
    revdep-rebuild

    # Yes, there's a risk of an infinite recursive loop here.
    script_emerge_retry

    # Update configuration files. This part might not be unattended...
    dispatch-conf
}

script_emerge_retry() {
    # Keep trying until we've got it!
    SER=0
    while test $? -ne 0; do
        logger "Gentoo install: emerge failed. Retry."
        emerge --resume
        SER=1
    done

    logger "Gentoo install: emerge succeeded. Continuing"

    if [[ $SER -ne 0 ]]; then
        # Don't let our SER interfere with deeper SERs.
	# We're done with it, anyhow.
        unset SER

        # So nice, we do it twice.
        script_emerge_post
        script_emerge_post
        # Really, though, since it may trigger emerges, we may need to clean up
        # after it.
    else
        unset SER
    fi
}

script_emerge_portage_update() {
    logger "Gentoo install: Updating portage"
    emerge --update --deep --newuse sys-apps/portage
    script_emerge_retry
}

script_emerge_update_world() {
    logger "Gentoo install: updating @world"
    emerge --update --deep --newuse @world
    script_emerge_retry
}

script_emerge_rebuild_world() {
    # Rebuild the whole thing with our latest compiler, binutils...
    logger "Gentoo install: rebuilding world"
    emerge -e @world
    script_emerge_retry
}

script_emerge() {
    logger "Gentoo install: emerging $*"
    emerge $*
    script_emerge_retry
}

# We need to finish the base configuration. After that, we can go on and try
# and update.


# We're going to skip over configuring and installing grub and the kernel. I'm
# assuming this has already been done, and that grub and the built kernel both
# comfortably reside under /boot. Why? Because doing so has saved me a ton of
# time on my own setup, this week.

# Write out configuration items.

script_write_fstab

# Real quick, enable swap.
swapon -a

script_conf_hostname

script_conf_net

script_conf_locales

script_em_sync

# We need these for post-emerge steps, but they're normally pulled in as
# dependencies of other things. For whatever reason, they're not in
# the stage 3 tarball. We'll oneshot-install them so we have them. Later,
# they'll either be scooped up as dependencies of other packages, or
# they'll be cleaned up as part of an emerge --depclean. Either way, we're
# not putting them in our world file.

logger "Gentoo install: One-shotting per-cleaner and python-updater"
emerge -1 app-admin/perl-cleaner app-admin/python-updater

# We need this for revdep-rebuild, which we'll want _immediately_ after
# updating portage.
script_emerge app-portage/gentoolkit

script_emerge_portage_update

logger "Gentoo install: Installing kernel-sources"
emerge $KERNEL_SOURCES

script_emerge_update_world

# Since we're rebasing the system with new CFLAGS, and _then_ rebuilding
# the _entire_ system twice to make sure we got everything, it's almost
# certainly best to go ahead and do this before we install any more packages.

# So nice, we do it twice.
script_emerge_rebuild_world
script_emerge_rebuild_world
# Really, though, we do it twice to pick up any two-step stragglers.

# OK, now on to the necessary system tools.

script_emerge app-admin/syslog-ng sys-process/vixie-cron net-misc/openssh net-misc/dhcpcd sys-apps/mlocate
rc-update add syslog-ng default
rc-update add vixie-cron default
rc-update add ssh default

# And not-so-necessary-but-oh-so-nice tools.
script_emerge app-admin/genlop sys-process/htop app-editors/vim app-portage/eix 

#GUI
script_emerge xfce-extra/xfce4-mixer xfce-extra/xfce4-taskmanager x11-themes/xfwm4-themes app-office/orage app-editors/mousepad xfce-extra/xfce4-power-manager x11-terms/xfce4-terminal xfce-base/thunar x11-terms/xfce4-terminal xfce-base/xfce4-meta
echo "exec startxfce4" > ~/.xinitrc

echo "SUCCESS!"
INNERSCRIPT

echo "Preparing chroot script"

# Write the script.
echo "$INNER_SCRIPT" > /mnt/gentoo/chroot_inner_script.sh

echo "Running chroot script"

# and run it. Wish us luck!
chroot /mnt/gentoo/ /bin/bash /chroot_inner_script.sh "$FS_ROOT_UUID" "$FS_BOOT_UUID" "$FS_SWAP_UUID" "$FS_HOME_UUID" "$ETC_CONFD_HOSTNAME" "$ETC_CONFD_NET_FILE_CONTENT" "$http_proxy" "$KERNEL_SOURCES"

if [[ $? -ne 0 ]]; then
    echo "chroot install script failed. Read output, collect logs, submit bugs..."
fi

