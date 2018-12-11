#! /bin/sh
#
# Copyright (c) 2013 Izumi Tsutsui.  All rights reserved.
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

BOOTDISK=sd0		# liveimage for USB disk

echo Start expanding fs size upto the actual disk size...

# make sure we are on ${BOOTDISK} on root
ROOTDEV=`sysctl -n kern.root_device`
if [ "${ROOTDEV}"X != ${BOOTDISK}X ] ; then
	echo Error: root file system device is not ${BOOTDISK}
	exit 1
fi

# make sure target disk is not mounted
if (mount | grep -q ^/dev/${BOOTDISK}a) ; then
	echo Error: /dev/${BOOTDISK}a is already mounted
	exit 1
fi

# mount tmpfs to create work file
if ! (mount | grep -q '^tmpfs on /tmp') ; then
	mount_tmpfs -s 1M tmpfs /tmp
fi

# get current disklabel
disklabel -r ${BOOTDISK} > /tmp/disklabel.${BOOTDISK}

# check disk name in disklabel
DISKNAME=`sed -n -e '/^disk: /s/.*: //p' /tmp/disklabel.${BOOTDISK}`
if [ "${DISKNAME}"X != "TeokureLiveImage"X ]; then
	echo Error: unexpected disk name: ${DISKNAME}
	exit 1
fi

echo ${DISKNAME} found in ${BOOTDISK} disklabel.

# get MBR label
fdisk -S ${BOOTDISK} > /tmp/mbrlabel.${BOOTDISK}
. /tmp/mbrlabel.${BOOTDISK}

# check MBR part id
if [ ${PART0ID} != "169" ]; then
	echo Error: unexpected MBR partition ID: ${PART0ID}
	exit 1
fi

ORIGIMAGEMB=5120
ORIGSWAPMB=512

ORIGIMAGESECTORS=$((${ORIGIMAGEMB} * 1024 * 1024 / 512))
ORIGSWAPSECTORS=$((${ORIGSWAPMB} * 1024 * 1024 / 512))

# check fdisk partition size
PART0END=$((${PART0START} + ${PART0SIZE}))
if [ ${PART0END} -ne ${ORIGIMAGESECTORS} ]; then
	echo Error: unexpected MBR partition size: ${PART0END}
	echo Expected original image size: ${ORIGIMAGESECTORS}
	exit 1
fi

# check original image size in label
TOTALSECTORS=`sed -n -e '/^total sectors: /s/.*: //p' /tmp/disklabel.${BOOTDISK}`
if [ ${TOTALSECTORS} -ne ${ORIGIMAGESECTORS} ]; then
	echo Error: unexpected total sectors in disklabel: ${TOTALSECTORS}
	echo Expected original total sectors: ${ORIGIMAGESECTORS}
	exit 1
fi

# get actual disk size from dmesg
BOOTDISKDMSG=`dmesg | grep "^${BOOTDISK}: .* sectors$"`
if [ "${BOOTDISKDMSG}"X = "X" ]; then
	echo Error: cannot find ${BOOTDISK} in dmesg
	exit 1
fi

IMAGESECTORS=`echo ${BOOTDISKDMSG} | awk '{print $(NF-1)}'`

echo Original image size: ${ORIGIMAGESECTORS} sectors
echo Target ${BOOTDISK} disk size: ${IMAGESECTORS} sectors

if [ ${ORIGIMAGESECTORS} -gt ${IMAGESECTORS} ]; then
	echo Error: ${BOOTDISK} is too small?
	exit 1
fi

# calculate new disk parameters
SWAPSECTORS=${ORIGSWAPSECTORS}

FSOFFSET=${PART0START}
BSDPARTSECTORS=$((${IMAGESECTORS} - ${FSOFFSET}))
FSSECTORS=$((${IMAGESECTORS} - ${SWAPSECTORS} - ${FSOFFSET}))
SWAPOFFSET=$((${FSOFFSET} + ${FSSECTORS}))
HEADS=64
SECTORS=32
CYLINDERS=$((${IMAGESECTORS} / (${HEADS} * ${SECTORS} ) ))

MBRCYLINDERS=$((${IMAGESECTORS} / ( ${BHEAD} * ${BSEC} ) ))

# prepare new disklabel proto
sed -e "s/^cylinders: [0-9]*$/cylinders: ${CYLINDERS}/" \
    -e "s/^total sectors: [0-9]*$/total sectors: ${IMAGESECTORS}/" \
    -e "s/^ a:  *[0-9]* *[0-9]* / a: ${FSSECTORS} ${FSOFFSET} /" \
    -e "s/^ b:  *[0-9]* *[0-9]* / b: ${SWAPSECTORS} ${SWAPOFFSET} /" \
    -e "s/^ c:  *[0-9]* *[0-9]* / c: ${BSDPARTSECTORS} ${FSOFFSET} /" \
    -e "s/^ d:  *[0-9]* / d: ${IMAGESECTORS} /" \
    /tmp/disklabel.${BOOTDISK} > /tmp/disklabel.${BOOTDISK}.new

# check original fs
echo Checking file system...
fsck_ffs -p /dev/r${BOOTDISK}a

# update MBR label
echo Updating partition size in MBR label...
fdisk -f -u -b ${MBRCYLINDERS}/${BHEAD}/${BSEC} \
    -0 -s ${PART0ID}/${FSOFFSET}/${BSDPARTSECTORS} \
    ${BOOTDISK}

# write updated disklabel
echo Updating partition size in disklabel...
disklabel -R ${BOOTDISK} /tmp/disklabel.${BOOTDISK}.new

# update fs size
echo Perform resize_ffs...
resize_ffs -p -y /dev/r${BOOTDISK}a
echo Done!
echo
echo Hit Enter to reboot...
read key
exec reboot
