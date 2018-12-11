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

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

DISKNAME=OS108LiveImage
IMAGEHOSTNAME=OS108
TIMEZONE=India

#TESTIMAGE=yes

usage()
{
	echo "usage: $0 <imagetype> <machine>"
	echo "supported imagetypes: " \
	     "usb (for USB memory), emu (for emulators)"
	echo "supported machine: amd64, i386"
	exit 1
}

if [ $# != 2 ]; then
	usage
fi

if [ "$1" != "usb" -a "$1" != "emu" ]; then
	usage
fi

IMAGE_TYPE=$1
MACHINE=$2

if [ ${IMAGE_TYPE}x = "usbx" ]; then
 HAVE_EXPANDFS_SCRIPT=yes	# put a script to expand image fssize
 EXPANDFS_SH=expand-image-fssize.sh
fi

#
# target dependent info
#
if [ "${MACHINE}" = "amd64" ]; then
 MACHINE_ARCH=x86_64
 MACHINE_GNU_PLATFORM=x86_64--netbsd		# for fdisk(8)
 TARGET_ENDIAN=le
 KERN_SET=kern-GENERIC
 EXTRA_SETS= # nothing
 USE_MBR=yes
 if [ ${IMAGE_TYPE}x = "emux" ]; then
  BOOTDISK=wd0		# for ATA disk
  OMIT_SWAPIMG=no	# include swap partition in output image
  #RTC_LOCALTIME=no	# assume emulators return UTC
 else
  BOOTDISK=sd0		# for USB disk
  #OMIT_SWAPIMG=yes	# no swap partition in output image
  OMIT_SWAPIMG=no	# XXX to use emulators to install packages
  RTC_LOCALTIME=yes	# use rtclocaltime=YES in rc.d(8)
 fi
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
 USE_MBR=yes
 if [ ${IMAGE_TYPE}x = "emux" ]; then
  BOOTDISK=wd0		# for ATA disk
  OMIT_SWAPIMG=no	# include swap partition in output image
  #RTC_LOCALTIME=no	# assume emulators return UTC
 else
  BOOTDISK=sd0		# for USB disk
  #OMIT_SWAPIMG=yes	# no swap partition in output image
  OMIT_SWAPIMG=no	# XXX to use emulators to install packages
  RTC_LOCALTIME=yes	# use rtclocaltime=YES in rc.d(8)
 fi
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
TOOLDIR=/usr/src/obj/tooldir.NetBSD-8.0-amd64

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
#RELEASEDIR=pub/NetBSD-daily/netbsd-8/201711301510Z

#
# misc build settings
#

# tools binaries
DISKLABEL=${TOOLDIR}/bin/nbdisklabel
FDISK=${TOOLDIR}/bin/${MACHINE_GNU_PLATFORM}-fdisk
SED=${TOOLDIR}/bin/nbsed
SUNLABEL=${TOOLDIR}/bin/nbsunlabel

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
IMAGEMB=5120			# 5120MB (4GB isn't enough for 8.0 + 2018Q2)
SWAPMB=512			# 512MB
IMAGESECTORS=$((${IMAGEMB} * 1024 * 1024 / 512))
SWAPSECTORS=$((${SWAPMB} * 1024 * 1024 / 512))

LABELSECTORS=0
if [ "${USE_MBR}" = "yes" ]; then
#	LABELSECTORS=63		# historical
#	LABELSECTORS=32		# aligned
	LABELSECTORS=2048	# align 1MiB for modern flash
fi
BSDPARTSECTORS=$((${IMAGESECTORS} - ${LABELSECTORS}))
FSSECTORS=$((${IMAGESECTORS} - ${SWAPSECTORS} - ${LABELSECTORS}))
FSOFFSET=${LABELSECTORS}
SWAPOFFSET=$((${LABELSECTORS} + ${FSSECTORS}))
FSSIZE=$((${FSSECTORS} * 512))
HEADS=64
SECTORS=32
CYLINDERS=$((${IMAGESECTORS} / ( ${HEADS} * ${SECTORS} ) ))
FSCYLINDERS=$((${FSSECTORS} / ( ${HEADS} * ${SECTORS} ) ))
SWAPCYLINDERS=$((${SWAPSECTORS} / ( ${HEADS} * ${SECTORS} ) ))

# fdisk(8) parameters
MBRSECTORS=63
MBRHEADS=255
MBRCYLINDERS=$((${IMAGESECTORS} / ( ${MBRHEADS} * ${MBRSECTORS} ) ))
MBRNETBSD=169

# makefs(8) parameters
BLOCKSIZE=16384
FRAGSIZE=4096
DENSITY=8192

echo creating ${IMAGE_TYPE} image for ${MACHINE}...

#
# get binary sets
#
URL_SETS=http://${FTPHOST}/${RELEASEDIR}/${MACHINE}/binary/sets
SETS="${KERN_SET} modules base etc comp games man misc tests text xbase xcomp xetc xfont xserver ${EXTRA_SETS}"
#SETS="${KERN_SET} modules base etc comp ${EXTRA_SETS}"
#SETS="${KERN_SET} base etc comp games man misc tests text xbase xcomp xetc xfont xserver ${EXTRA_SETS}"
#SETS="${KERN_SET} base etc comp ${EXTRA_SETS}"
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
kernfs		/kern		kernfs	rw		0 0
ptyfs		/dev/pts	ptyfs	rw		0 0
procfs		/proc		procfs	rw		0 0
/dev/cd0a	/cdrom		cd9660	ro,noauto	0 0
tmpfs		/tmp		tmpfs	rw,-s=128M	0 0
tmpfs		/var/shm	tmpfs	rw,-sram%25	0 0
EOF
${CP} ${WORKDIR}/fstab  ${TARGETROOTDIR}/etc

echo Setting liveimage specific configurations in /etc/rc.conf...
${CAT} ${TARGETROOTDIR}/etc/rc.conf | \
    ${SED} -e 's/rc_configured=NO/rc_configured=YES/' > ${WORKDIR}/rc.conf
if [ ${RTC_LOCALTIME}x = "yesx" ]; then
	echo rtclocaltime=YES		>> ${WORKDIR}/rc.conf
else
	echo #rtclocaltime=YES		>> ${WORKDIR}/rc.conf
fi
echo hostname=${IMAGEHOSTNAME}		>> ${WORKDIR}/rc.conf
echo dhcpcd=YES				>> ${WORKDIR}/rc.conf
${CP} ${WORKDIR}/rc.conf ${TARGETROOTDIR}/etc

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
./cdrom				type=dir  mode=0755
./kern				type=dir  mode=0755
./netbsd			type=file mode=0755
./proc				type=dir  mode=0755
./tmp				type=dir  mode=1777
EOF

if [ ${HAVE_EXPANDFS_SCRIPT}x = "yesx" ]; then
	echo Preparing ${EXPANDFS_SH} script...
	${SED}  -e "s/@@BOOTDISK@@/${BOOTDISK}/"			\
		-e "s/@@DISKNAME@@/${DISKNAME}/"			\
		-e "s/@@MBRNETBSD@@/${MBRNETBSD}/"			\
		-e "s/@@IMAGEMB@@/${IMAGEMB}/"				\
		-e "s/@@SWAPMB@@/${SWAPMB}/"				\
		-e "s/@@HEADS@@/${HEADS}/"				\
		-e "s/@@SECTORS@@/${SECTORS}/"				\
		< ./${EXPANDFS_SH}.in > ${TARGETROOTDIR}/${EXPANDFS_SH}
	echo ./${EXPANDFS_SH}	type=file mode=755 >> ${WORKDIR}/spec
fi

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

if [ "${OMIT_SWAPIMG}x" != "yesx" ]; then
	echo Creating swap fs
	${DD} if=/dev/zero of=${WORKDIR}/swap seek=$((${SWAPSECTORS} - 1)) count=1
fi

if [ ${LABELSECTORS} != 0 ]; then
	echo creating MBR labels...
	${DD} if=/dev/zero of=${IMAGE}.mbr count=1 \
	    seek=$((${IMAGESECTORS} - 1))
	${FDISK} -f -u \
	    -b ${MBRCYLINDERS}/${MBRHEADS}/${MBRSECTORS} \
	    -0 -a -s ${MBRNETBSD}/${FSOFFSET}/${BSDPARTSECTORS} \
	    -i -c ${TARGETROOTDIR}/usr/mdec/mbr \
	    -F ${IMAGE}.mbr
	${DD} if=${IMAGE}.mbr of=${WORKDIR}/mbrsectors count=${LABELSECTORS}
	${RM} -f ${IMAGE}.mbr
	echo Copying target disk image...
	${CAT} ${WORKDIR}/mbrsectors ${WORKDIR}/rootfs > ${IMAGE}
	if [ "${OMIT_SWAPIMG}x" != "yesx" ]; then
		${CAT} ${WORKDIR}/swap >> ${IMAGE}
	fi
else
	echo Copying target disk image...
	${CP} ${WORKDIR}/rootfs ${IMAGE}
	if [ "${OMIT_SWAPIMG}x" != "yesx" ]; then
		${CAT} ${WORKDIR}/swap >> ${IMAGE}
	fi
fi

if [ ! -z ${USE_SUNLABEL} ]; then
	echo Creating sun disklabel...
	printf 'V ncyl %d\nV nhead %d\nV nsect %d\na %d %d/0/0\nb %d %d/0/0\nW\n' \
	    ${CYLINDERS} ${HEADS} ${SECTORS} \
	    ${FSOFFSET} ${FSCYLINDERS} ${FSCYLINDERS} ${SWAPCYLINDERS} | \
	    ${SUNLABEL} -nq ${IMAGE}
fi

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
b:    ${SWAPSECTORS} ${SWAPOFFSET} swap
c:    ${BSDPARTSECTORS} ${FSOFFSET} unused 0 0
d:    ${IMAGESECTORS} 0 unused 0 0
EOF

${DISKLABEL} -R -F -M ${MACHINE} ${IMAGE} ${WORKDIR}/labelproto

# XXX some ${MACHINE} needs disklabel for installboot
#${TOOLDIR}/bin/nbinstallboot -vm ${MACHINE} ${MACHINE}.img \
#    ${TARGETROOTDIR}/usr/mdec/${PRIMARY_BOOT}

echo Creating image \"${IMAGE}\" complete.

if [ "${TESTIMAGE}" != "yes" ]; then exit; fi

#
# for test on emulators...
#
if [ "${MACHINE}" = "amd64" -a -x /usr/pkg/bin/qemu-system-x86_64 ]; then
	qemu-system-x86_64 -hda ${IMAGE} -boot c
fi
if [ "${MACHINE}" = "i386" -a -x /usr/pkg/bin/qemu ]; then
	qemu -hda ${IMAGE} -boot c
fi
