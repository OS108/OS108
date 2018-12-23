#! /bin/sh
#
# Install MATE Desktop & SLIM from wip pkgsrc and install theme for OS108
#
echo ALLOW_VULNERABLE_PACKAGES=yes >> /usr/pkgsrc/mk/defaults/mk.conf
cd /usr/pkgsrc/x11/slim/ && make install
cp /usr/pkg/share/examples/rc.d/slim /etc/rc.d
cd $HOME && test -f .xinitrc || touch .xinitrc
echo mate-session >> $HOME/.xinitrc
cd $HOME && ln .xinitrc .xsession
mkdir /home/OS108
cd /home/OS108
curl -LO https://github.com/OS108/OS108/raw/master/os108-slim-theme-default/os108-default/background.jpg
curl -LO https://github.com/OS108/OS108/raw/master/os108-slim-theme-default/os108-default/panel.png
curl -LO https://github.com/OS108/OS108/raw/master/os108-slim-theme-default/os108-default/slim.theme
rm /usr/pkg/share/slim/themes/default/*
cp /home/OS108/* /usr/pkg/share/themes/default/
echo slim=YES >> /etc/rc.conf
echo dbus=YES >> /etc/rc.conf
echo hal=YES >> /etc/rc.conf
echo famd=YES >> /etc/rc.conf
pkgin -y install mate-desktop mate-notification-daemon mate-terminal mate-panel mate-session-manager mate-icon-theme mate-control-center mate-power-manager mate-utils mate-calc caja hal fam atril gvfs-goa gvfs-google gvfs-nfs gvfs-smb
cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/hal /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
echo Done!
