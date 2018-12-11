#! /bin/sh
#
# Copyright (c) 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018 Izumi Tsutsui.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# a dumb script to build a qemu image that configures liveimage automatically
#
#  This script creates a NetBSD/i386 disk image for qemu that is intended
#  to configure the target liveimage without prompts.
#
#  It will mount the target liveimage on /targetroot,
#  also mount setupliveimage on /targetroot/mnt,
#  and then just invoke inst.sh in setupliveimage.
#  The setup script checks "vioif0" and in that case
#  it copies xorg.conf.vesa to /etc/X11.
#
# expected usage:
# % qemu-system-i386 -m 512 \
#   -hda obj/work.i386.qemu/liveimage-i386-qemu-YYYYMMDD.img \
#   -hdb obj/work.i386.usb/liveimage-i386-usb-YYYYMMDD.img \
#   -hdc obj/work.setupliveimage/setupliveimage-YYYYMMDD.fs
#
# for VirtualBox image:
# % qemu-system-i386 -m 512 \
#   -hda obj/work.i386.qemu/liveimage-i386-qemu-YYYYMMDD.img \
#   -hdb obj/liveimage-i386-vbox-YYYYMMDD.img \
#   -hdc obj/work.setupliveimage/setupliveimage-YYYYMMDD.fs
#   -net nic,model=virtio
#

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

DISKNAME=TeokureBuilder
IMAGEHOSTNAME=teokure
TIMEZONE=Japan
IMAGE_TYPE=qemu

usage()
{
	echo "usage: $0 <machine>"
	echo "supported machine: amd64, i386"
	exit 1
}

if [ $# != 1 ]; then
	usage
fi

MACHINE=$1

#
# target dependent info
#
if [ "${MACHINE}" = "amd64" ]; then
 MACHINE_ARCH=x86_64
 MACHINE_GNU_PLATFORM=x86_64--netbsd		# for fdisk(8)
 TARGET_ENDIAN=le
 KERN_SET=kern-GENERIC
 EXTRA_SETS= # nothing
 BOOTDISK=wd0		# for USB disk
 PRIMARY_BOOT=bootxx_ffsv1
 SECONDARY_BOOT=boot
 SECONDARY_BOOT_ARG= # nothing
fi

if [ "${MACHINE}" = "i386" ]; then
 MACHINE_ARCH=i386
 MACHINE_GNU_PLATFORM=i486--netbsdelf		# for fdisk(8)
 TARGET_ENDIAN=le
 KERN_SET=kern-GENERIC
 EXTRA_SETS= # nothing
 BOOTDISK=wd0		# for ATA disk
 PRIMARY_BOOT=bootxx_ffsv1
 SECONDARY_BOOT=boot
 SECONDARY_BOOT_ARG= # nothing
fi

if [ -z ${MACHINE_ARCH} ]; then
	echo "Unsupported MACHINE (${MACHINE})"
	exit 1
fi

#
# tooldir settings
#
#NETBSDSRCDIR=/usr/src
#TOOLDIR=/usr/tools/${MACHINE_ARCH}

if [ -z ${NETBSDSRCDIR} ]; then
	NETBSDSRCDIR=/usr/src
fi

if [ -z ${TOOLDIR} ]; then
	_HOST_OSNAME=`uname -s`
	_HOST_OSREL=`uname -r`
	_HOST_ARCH=`uname -p 2> /dev/null || uname -m`
	TOOLDIRNAME=tooldir.${_HOST_OSNAME}-${_HOST_OSREL}-${_HOST_ARCH}
	TOOLDIR=${NETBSDSRCDIR}/obj.${MACHINE}/${TOOLDIRNAME}
	if [ ! -d ${TOOLDIR} ]; then
		TOOLDIR=${NETBSDSRCDIR}/${TOOLDIRNAME}
	fi
fi

if [ ! -d ${TOOLDIR} ]; then
	echo 'set TOOLDIR first'; exit 1
fi
if [ ! -x ${TOOLDIR}/bin/nbmake-${MACHINE} ]; then
	echo 'build tools in ${TOOLDIR} first'; exit 1
fi

#
# info about ftp to get binary sets
#
#FTPHOST=ftp.NetBSD.org
#FTPHOST=ftp.jp.NetBSD.org
#FTPHOST=ftp7.jp.NetBSD.org
FTPHOST=cdn.NetBSD.org
#FTPHOST=nyftp.NetBSD.org
RELEASE=8.0
RELEASEDIR=pub/NetBSD/NetBSD-${RELEASE}
#RELEASEDIR=pub/NetBSD-daily/netbsd-7/201507032200Z

#
# misc build settings
#

# tools binaries
DISKLABEL=${TOOLDIR}/bin/nbdisklabel
FDISK=${TOOLDIR}/bin/${MACHINE_GNU_PLATFORM}-fdisk
SED=${TOOLDIR}/bin/nbsed

# host binaries
CAT=cat
CP=cp
DD=dd
FTP=ftp
#FTP=tnftp
FTP_OPTIONS=-V
MKDIR=mkdir
RM=rm
SH=sh
TAR=tar

# working directories
if [ "${OBJDIR}"X = "X" ]; then
	OBJDIR=.
fi
TARGETROOTDIR=${OBJDIR}/targetroot.${MACHINE}.${IMAGE_TYPE}
DOWNLOADDIR=download.${MACHINE}
WORKDIR=${OBJDIR}/work.${MACHINE}.${IMAGE_TYPE}
IMAGE=${WORKDIR}/liveimage-${MACHINE}-${IMAGE_TYPE}-${REVISION}.img

#
# target image size settings
#
IMAGEMB=250			# minimum
IMAGESECTORS=$((${IMAGEMB} * 1024 * 1024 / 512))
# no swap

BSDPARTSECTORS=${IMAGESECTORS}
FSSECTORS=${IMAGESECTORS}
FSOFFSET=0
FSSIZE=$((${FSSECTORS} * 512))
HEADS=64
SECTORS=32
CYLINDERS=$((${IMAGESECTORS} / ( ${HEADS} * ${SECTORS} ) ))
FSCYLINDERS=$((${FSSECTORS} / ( ${HEADS} * ${SECTORS} ) ))

# makefs(8) parameters
BLOCKSIZE=16384
FRAGSIZE=4096
DENSITY=8192

echo creating ${IMAGE_TYPE} image for ${MACHINE}...

#
# get binary sets
#
URL_SETS=http://${FTPHOST}/${RELEASEDIR}/${MACHINE}/binary/sets
SETS="${KERN_SET} base etc"
${MKDIR} -p ${DOWNLOADDIR}
for set in ${SETS}; do
	if [ ! -f ${DOWNLOADDIR}/${set}.tgz ]; then
		echo Fetching ${set}.tgz...
		${FTP} ${FTP_OPTIONS} \
		    -o ${DOWNLOADDIR}/${set}.tgz ${URL_SETS}/${set}.tgz
	fi
done

#
# create targetroot
#
echo Removing ${TARGETROOTDIR}...
${RM} -rf ${TARGETROOTDIR}
${MKDIR} -p ${TARGETROOTDIR}
for set in ${SETS}; do
	echo Extracting ${set}...
	${TAR} -C ${TARGETROOTDIR} -zxf ${DOWNLOADDIR}/${set}.tgz
done
# XXX /var/spool/ftp/hidden is unreadable
chmod u+r ${TARGETROOTDIR}/var/spool/ftp/hidden

# copy secondary boot for bootstrap
# XXX probabry more machine dependent
if [ ! -z ${SECONDARY_BOOT} ]; then
	echo Copying secondary boot...
	${CP} ${TARGETROOTDIR}/usr/mdec/${SECONDARY_BOOT} ${TARGETROOTDIR}
fi

#
# create target fs
#
echo Removing ${WORKDIR}...
${RM} -rf ${WORKDIR}
${MKDIR} -p ${WORKDIR}

echo Preparing /etc/fstab...
${CAT} > ${WORKDIR}/fstab <<EOF
/dev/${BOOTDISK}a	/		ffs	rw,log		1 1
/dev/${BOOTDISK}b	none		none	sw		0 0
ptyfs		/dev/pts	ptyfs	rw		0 0
kernfs		/kern		kernfs	rw		0 0
procfs		/proc		procfs	rw		0 0
tmpfs		/tmp		tmpfs	rw		0 0
EOF
${CP} ${WORKDIR}/fstab  ${TARGETROOTDIR}/etc

echo Preparing setup script...
${CAT} > ${WORKDIR}/etc.rc <<EOF
export PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/pkg/sbin:/usr/pkg/bin
export PATH=\${PATH}:/usr/X11R7/bin:/usr/local/sbin:/usr/local/bin
set -o emacs
stty erase ^H
mount -o async /dev/wd1a /targetroot
mount -r /dev/wd2a /targetroot/mnt
chroot /targetroot /bin/sh /mnt/inst.sh
IFNAME=\`ifconfig -l | awk '{print \$1}'\`
if [ "\${IFNAME}"x = "vioif0"x ]; then
	cp /targetroot/mnt/etc/xorg.conf.vesa /targetroot/etc/X11/xorg.conf
fi
halt -p
EOF
rm -f ${TARGETROOTDIR}/etc/rc
${CP} ${WORKDIR}/etc.rc  ${TARGETROOTDIR}/etc/rc

echo Setting localtime...
ln -sf /usr/share/zoneinfo/${TIMEZONE} ${TARGETROOTDIR}/etc/localtime

echo Preparing spec file for makefs...
${CAT} ${TARGETROOTDIR}/etc/mtree/* | \
	${SED} -e 's/ size=[0-9]*//' > ${WORKDIR}/spec
${SH} ${TARGETROOTDIR}/dev/MAKEDEV -s all | \
	${SED} -e '/^\. type=dir/d' -e 's,^\.,./dev,' >> ${WORKDIR}/spec
# spec for optional files/dirs
${CAT} >> ${WORKDIR}/spec <<EOF
./boot				type=file mode=0444
./kern				type=dir  mode=0755
./netbsd			type=file mode=0755
./proc				type=dir  mode=0755
./targetroot			type=dir  mode=0755
./tmp				type=dir  mode=1777
EOF

echo Creating rootfs...
${TOOLDIR}/bin/nbmakefs -M ${FSSIZE} -B ${TARGET_ENDIAN} \
	-F ${WORKDIR}/spec -N ${TARGETROOTDIR}/etc \
	-o bsize=${BLOCKSIZE},fsize=${FRAGSIZE},density=${DENSITY} \
	${WORKDIR}/rootfs ${TARGETROOTDIR}

if [ ${PRIMARY_BOOT}x != "x" ]; then
echo Installing bootstrap...
${TOOLDIR}/bin/nbinstallboot -v -m ${MACHINE} ${WORKDIR}/rootfs \
    ${TARGETROOTDIR}/usr/mdec/${PRIMARY_BOOT} ${SECONDARY_BOOT_ARG}
fi

echo Copying target disk image...
${CP} ${WORKDIR}/rootfs ${IMAGE}

echo Creating disklabel...
${CAT} > ${WORKDIR}/labelproto <<EOF
type: ESDI
disk: ${DISKNAME}
label: 
flags:
bytes/sector: 512
sectors/track: ${SECTORS}
tracks/cylinder: ${HEADS}
sectors/cylinder: $((${HEADS} * ${SECTORS}))
cylinders: ${CYLINDERS}
total sectors: ${IMAGESECTORS}
rpm: 3600
interleave: 1
trackskew: 0
cylinderskew: 0
headswitch: 0           # microseconds
track-to-track seek: 0  # microseconds
drivedata: 0 

8 partitions:
#        size    offset     fstype [fsize bsize cpg/sgs]
a:    ${FSSECTORS} ${FSOFFSET} 4.2BSD ${FRAGSIZE} ${BLOCKSIZE} 128
c:    ${BSDPARTSECTORS} ${FSOFFSET} unused 0 0
d:    ${IMAGESECTORS} 0 unused 0 0
EOF

${DISKLABEL} -R -F -M ${MACHINE} ${IMAGE} ${WORKDIR}/labelproto

echo Creating image \"${IMAGE}\" complete.
