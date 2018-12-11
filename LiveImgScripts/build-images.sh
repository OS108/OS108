#! /bin/sh
#
# a stupid script to automate building images
#

if [ -f REVISION ]; then
	. ./REVISION
fi
if [ "${REVISION}"X = "X" ]; then
	REVISION=`date +%C%y%m%d`
fi

CURDIR=`pwd`
# assume proper symlinks are prepared in ${CURDIR}
NETBSDSRCDIR=${CURDIR}/src
OBJDIR=${CURDIR}
if [ -e ${CURDIR}/obj ]; then
	OBJDIR=${CURDIR}/obj
fi
VBOXDIR=${CURDIR}/vbox
VDIDIR=${CURDIR}/vdi
VMDKDIR=${CURDIR}/vmdk

#GZIP=/usr/bin/gzip
GZIP=/usr/bin/pigz	# for threads
MD5=/usr/bin/md5
#MD5=/usr/bin/md5sum
SH=/bin/sh
ZIP=/usr/pkg/bin/zip
#ZIP=/usr/local/bin/zip

QEMU_I386=/usr/pkg/bin/qemu-system-i386
QEMU_X86_64=/usr/pkg/bin/qemu-system-x86_64
QEMU_IMG=/usr/pkg/bin/qemu-img
QEMU_MEM=1024

_HOST_OSNAME=`uname -s`
_HOST_OSREL=`uname -r`
_HOST_ARCH=`uname -p 2> /dev/null || uname -m`
TOOLDIRNAME=tooldir.${_HOST_OSNAME}-${_HOST_OSREL}-${_HOST_ARCH}

TOOLDIR_I386=${NETBSDSRCDIR}/obj.i386/${TOOLDIRNAME}
TOOLDIR_AMD64=${NETBSDSRCDIR}/obj.amd64/${TOOLDIRNAME}
#TOOLDIR_I386=/usr/tools/i386
#TOOLDIR_AMD64=/usr/tools/x86_64

# build "setup liveimage" image
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mksetupliveimage.sh

# build and setup amd64 USB liveimage
TOOLDIR=${TOOLDIR_AMD64} OBJDIR=${OBJDIR} ${SH} mkimagebuilder.sh amd64
TOOLDIR=${TOOLDIR_AMD64} OBJDIR=${OBJDIR} ${SH} mkliveimage.sh usb amd64
${QEMU_X86_64} -m ${QEMU_MEM} \
 -drive file=${OBJDIR}/work.amd64.qemu/liveimage-amd64-qemu-${REVISION}.img,index=0,media=disk,format=raw,cache=unsafe \
 -drive file=${OBJDIR}/work.amd64.usb/liveimage-amd64-usb-${REVISION}.img,index=1,media=disk,format=raw,cache=unsafe \
 -drive file=${OBJDIR}/work.setupliveimage/setupliveimage-${REVISION}.fs,index=2,media=disk,format=raw,cache=unsafe

# build and setup i386 USB/emulator/virtualbox/vmdk images
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mkimagebuilder.sh i386
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mkliveimage.sh usb i386
TOOLDIR=${TOOLDIR_I386} OBJDIR=${OBJDIR} ${SH} mkliveimage.sh emu i386
${QEMU_I386} -m ${QEMU_MEM} \
 -drive file=${OBJDIR}/work.i386.qemu/liveimage-i386-qemu-${REVISION}.img,index=0,media=disk,format=raw,cache=unsafe \
 -drive file=${OBJDIR}/work.i386.usb/liveimage-i386-usb-${REVISION}.img,index=1,media=disk,format=raw,cache=unsafe \
 -drive file=${OBJDIR}/work.setupliveimage/setupliveimage-${REVISION}.fs,index=2,media=disk,format=raw,cache=unsafe
${QEMU_I386} -m ${QEMU_MEM} \
 -drive file=${OBJDIR}/work.i386.qemu/liveimage-i386-qemu-${REVISION}.img,index=0,media=disk,format=raw,cache=unsafe \
 -drive file=${OBJDIR}/work.i386.emu/liveimage-i386-emu-${REVISION}.img,index=1,media=disk,format=raw,cache=unsafe \
 -drive file=${OBJDIR}/work.setupliveimage/setupliveimage-${REVISION}.fs,index=2,media=disk,format=raw,cache=unsafe

echo Converting from raw to vmdk...
rm -f ${VDIDIR}/liveimage-i386-vmdk-${REVISION}.vmdk
${QEMU_IMG} convert -O vmdk \
 ${OBJDIR}/work.i386.emu/liveimage-i386-emu-${REVISION}.img \
 ${VMDKDIR}/liveimage-i386-vmdk-${REVISION}.vmdk

echo Converting from raw to vdi...
rm -f ${VDIDIR}/liveimage-i386-vbox-${REVISION}.vdi
#LD_LIBRARY_PATH=${VBOXDIR}/usr/lib/virtualbox \
# ${VBOXDIR}/usr/lib/virtualbox/VBoxManage convertfromraw --format VDI \
# ${OBJDIR}/work.i386.emu/liveimage-i386-emu-${REVISION}.img \
# ${VDIDIR}/liveimage-i386-vbox-${REVISION}.vdi
${VBOXDIR}/vbox-img convert --srcformat RAW --dstformat VDI \
 --srcfilename ${OBJDIR}/work.i386.emu/liveimage-i386-emu-${REVISION}.img \
 --dstfilename ${VDIDIR}/liveimage-i386-vbox-${REVISION}.vdi

# prepare compressed images (and omit swap for USB images) for distribution

echo Preparing compressed image files...
IMAGEMB=5120			# 5120MB (4GB isn't enough for 8.0 + 2018Q2)
SWAPMB=512			# 512MB
USBMB=$((${IMAGEMB} - ${SWAPMB}))
IMAGEDIR=${CURDIR}/images/${REVISION}

rm -rf ${IMAGEDIR}
mkdir -p ${IMAGEDIR}

(cd ${VDIDIR} && \
 ${ZIP} -9 ${IMAGEDIR}/liveimage-i386-vbox-${REVISION}.zip  \
  liveimage-i386-vbox-${REVISION}.vdi)

(cd ${VMDKDIR} && \
 ${ZIP} -9 ${IMAGEDIR}/liveimage-i386-vmdk-${REVISION}.zip  \
  liveimage-i386-vmdk-${REVISION}.vmdk)

dd if=${OBJDIR}/work.i386.usb/liveimage-i386-usb-${REVISION}.img count=${USBMB} bs=1m \
    | ${GZIP} -9c > ${IMAGEDIR}/liveimage-i386-usb-${REVISION}.img.gz

dd if=${OBJDIR}/work.amd64.usb/liveimage-amd64-usb-${REVISION}.img count=${USBMB} bs=1m \
    | ${GZIP} -9c > ${IMAGEDIR}/liveimage-amd64-usb-${REVISION}.img.gz

${GZIP} -9c ${OBJDIR}/work.i386.emu/liveimage-i386-emu-${REVISION}.img \
    > ${IMAGEDIR}/liveimage-i386-emu-${REVISION}.img.gz

${GZIP} -9c ${OBJDIR}/work.setupliveimage/setupliveimage-${REVISION}.fs \
    > ${IMAGEDIR}/setupliveimage-${REVISION}.fs.gz

(cd ${IMAGEDIR} && ${MD5} \
  liveimage-amd64-usb-${REVISION}.img.gz \
  liveimage-i386-emu-${REVISION}.img.gz \
  liveimage-i386-usb-${REVISION}.img.gz \
  liveimage-i386-vbox-${REVISION}.zip \
  liveimage-i386-vmdk-${REVISION}.zip \
  setupliveimage-${REVISION}.fs.gz \
   > MD5)
