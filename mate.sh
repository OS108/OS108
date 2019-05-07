#! /bin/sh
#
# Install MATE Desktop & SLIM from wip pkgsrc and install theme for OS108
#
cp /cdrom/amd64/binary/sets/pkgs/pkg_install.conf /etc
cp /cdrom/amd64/binary/sets/pkgs/pkgin-0.11.6.tgz /root
cp /cdrom/amd64/binary/sets/pkgs/pkg_install-20180425.tgz /root
pkg_add -v /root/pkg_install-20180425.tgz
pkg_add -v /root/pkgin-0.11.6.tgz
mkdir /root/repo
cp /cdrom/amd64/binary/sets/pkgs/* /root/repo
rm /usr/pkg/etc/pkgin/repositories.conf
cp /cdrom/amd64/binary/sets/pkgs/repositories_MATE.conf /usr/pkg/etc/pkgin/repositories.conf
pkgin update
pkgin -y install nano sudo mate fam vlc2 compton midori mate-system-monitor mozilla-rootcerts-openssl wpa_gui sysupgrade libreoffice transmission-gtk
pkg_add -v /root/repo/slim-1.3.6nb2
rm /usr/pkg/etc/pkgin/repositories.conf
cp /cdrom/amd64/binary/sets/pkgs/repositories.conf /usr/pkg/etc/pkgin/
echo wscons=YES >> /etc/rc.conf
echo amd=YES >> /etc/rc.conf
echo dbus=YES >> /etc/rc.conf
echo famd=YES >> /etc/rc.conf
echo avahidaemon=YES >> /etc/rc.conf
echo rpcbind=YES >> /etc/rc.conf
echo slim=YES >> /etc/rc.conf
echo ipv6addrctl=YES >> /etc/rc.conf
echo ipv6addrctl_policy=ipv4_prefer >> /etc/rc.conf
echo "setvar wskbd bell.volume 0" >> /etc/wscons.conf
echo "setvar wskbd bell.pitch 0" >> /etc/wscons.conf
cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/avahidaemon /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/slim /etc/rc.d
visudo -c -q -f /cdrom/amd64/binary/sets/pkgs/mysudo && cp /cdrom/amd64/binary/sets/pkgs/mysudo /usr/pkg/etc/sudoers.d && chmod 600 /usr/pkg/etc/sudoers.d/mysudo
groupinfo wheel >> /root/users.list
sed -n '/^members[[:blank:]]*/{ s///; s/,[[:blank:]]/,/g; y/,/\n/; p; }' /root/users.list >> /root/final.list
USERS=`cat /root/final.list`
for user in ${USERS}; do

	if [ ${user} = root ] ; then
		echo skip setting root
	else 
		echo exec ck-launch-session dbus-launch --exit-with-session mate-session >> /home/${user}/.xinitrc	
	fi
	 
done
mkdir /amd
mkdir /media
mkdir /etc/amd
cp /cdrom/amd64/binary/sets/pkgs/amd.conf /etc
cp /cdrom/amd64/binary/sets/pkgs/media /etc/amd
for user in ${USERS}; do

	if [ ${user} = root ] ; then
		echo skip setting root
	else 
		echo [ /home/${user}/media ] >> /etc/amd.conf
		echo map_name =       media >> /etc/amd.conf
	fi
done
rm /usr/pkg/share/slim/themes/default/*
cp /root/repo/background.jpg /usr/pkg/share/slim/themes/default/
cp /root/repo/panel.png /usr/pkg/share/slim/themes/default/
cp /root/repo/slim.theme /usr/pkg/share/slim/themes/default/
for user in ${USERS}; do

	if [ ${user} = root ] ; then
		echo skip setting root
	else
		mkdir /home/${user}/Desktop
		chown ${user} /home/${user}/Desktop 
		cp /root/repo/WiFI\ Manager.desktop /home/${user}/Desktop
		chown ${user} /home/${user}/Desktop/WiFI\ Manager.desktop
		usermod -G operator ${user}		
	fi
done
mv /usr/pkg/share/backgrounds/mate/desktop/Stripes.png /usr/pkg/share/backgrounds/mate/desktop/Stripes.png_backup
cp /root/repo/bg.png /usr/pkg/share/backgrounds/mate/desktop/Stripes.png
rm -rf /root/repo
rm /root/users.list
rm /root/final.list
rm /root/pkgin-0.11.6.tgz
rm /root/pkg_install-20180425.tgz
sysctl -w kern.defcorename=/tmp/%n.core
compton \
        --config /dev/null \
        --backend glx \
        --vsync opengl-swc \
        --detect-rounded-corners \
        --detect-client-leader \
        --detect-transient \
        --detect-client-opacity \
        --glx-no-stencil \
        --glx-swap-method undefined \
        --unredir-if-possible \
        --unredir-if-possible-exclude "class_g = 'Mate-screensaver'" \
        --inactive-opacity-override \
        --mark-wmwin-focused \
        --mark-ovredir-focused \
        --use-ewmh-active-win \
        -r 10 -o 0.225 -l -12 -t -12 \
        -c -C -G \
        --fading \
        --fade-delta=4 \
        --fade-in-step=0.03 \
        --fade-out-step=0.03 \
        --shadow-exclude "! name~=''" \
        --shadow-exclude "name = 'Notification'" \
        --shadow-exclude "name = 'Plank'" \
        --shadow-exclude "name = 'Docky'" \
        --shadow-exclude "name = 'Kupfer'" \
        --shadow-exclude "name *= 'compton'" \
        --shadow-exclude "class_g = 'albert'" \
        --shadow-exclude "class_g = 'Conky'" \
        --shadow-exclude "class_g = 'Kupfer'" \
        --shadow-exclude "class_g = 'Synapse'" \
        --shadow-exclude "class_g ?= 'Notify-osd'" \
        --shadow-exclude "class_g ?= 'Cairo-dock'" \
        --shadow-exclude "class_g = 'Cairo-clock'" \
	--shadow-exclude "_GTK_FRAME_EXTENTS@:c"
shutdown -r now
