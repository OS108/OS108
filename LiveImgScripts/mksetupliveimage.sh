#! /bin/sh
#
# Copyright (c) 2012, 2013, 2014, 2015 Izumi Tsutsui.  All rights reserved.
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

# source and target
INSTSH=inst.sh
FILESDIR=liveimagefiles
if [ "${OBJDIR}"X = "X" ]; then
	OBJDIR=.
fi
WORKDIR=${OBJDIR}/work.setupliveimage
IMAGE=${WORKDIR}/setupliveimage-${REVISION}.fs

#
# tooldir settings
#
MACHINE_ARCH=i386
MACHINE=i386
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

DISKLABEL=${TOOLDIR}/bin/nbdisklabel
MAKEFS=${TOOLDIR}/bin/nbmakefs
MKDIR=mkdir
RM=rm

#
# target image size settings
#
FSMB=1500
FSSECTORS=$((${FSMB} * 1024 * 1024 / 512))
FSSIZE=$((${FSSECTORS} * 512))
FSOFFSET=0

HEADS=64
SECTORS=32
CYLINDERS=$((${FSSECTORS} / ( ${HEADS} * ${SECTORS} ) ))

# makefs(8) parameters
TARGET_ENDIAN=le
BLOCKSIZE=16384
FRAGSIZE=4096
DENSITY=8192

echo Removing ${WORKDIR}...
${RM} -rf ${WORKDIR}
${MKDIR} -p ${WORKDIR}

echo Creating rootfs...
${MAKEFS} -M ${FSSIZE} -B ${TARGET_ENDIAN} \
	-o bsize=${BLOCKSIZE},fsize=${FRAGSIZE},density=${DENSITY} \
	${IMAGE} ${FILESDIR}

echo Creating disklabel...
LABELPROTO=${WORKDIR}/labelproto
cat > ${LABELPROTO} <<EOF
type: ESDI
disk: SetupLiveImage
label: 
flags:
bytes/sector: 512
sectors/track: ${SECTORS}
tracks/cylinder: ${HEADS}
sectors/cylinder: $((${HEADS} * ${SECTORS}))
cylinders: ${CYLINDERS}
total sectors: ${FSSECTORS}
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
c:    ${FSSECTORS} ${FSOFFSET} unused 0 0
EOF

${DISKLABEL} -R -F -M ${MACHINE} ${IMAGE} ${LABELPROTO}
rm -f ${LABELPROTO}

echo Creating image \"${IMAGE}\" complete.
