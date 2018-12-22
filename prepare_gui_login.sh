#! /bin/sh
#
# Install SLIM from wip pkgsrc and install theme for OS108
#

PKGSRCDIR=/usr/pkgsrc
RELEASE=8.0
PKGSRC_VER=${RELEASE}_2018Q3
PACKAGESDIR_X86_64=${PKGSRCDIR}/packages/x86_64-${PKGSRC_VER}/All
cd /usr/pkgsrc/x11/slim/
make install
cp /usr/pkg/share/examples/rc.d/slim /etc/rc.d
cd ~
test -f .xinitrc || touch .xinitrc 
ln .xinitrc .xsession
mkdir /home/OS108
cd /home/OS108
curl -O https://github.com/OS108/OS108/raw/master/os108-slim-theme-default/os108-default/background.jpg
curl -O https://github.com/OS108/OS108/raw/master/os108-slim-theme-default/os108-default/panel.png
curl -O https://github.com/OS108/OS108/raw/master/os108-slim-theme-default/os108-default/slim.theme
rm /usr/pkg/share/slim/themes/default/*
cp /home/OS108/* /usr/pkg/share/themes/default/
echo Done!
