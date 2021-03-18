#! /bin/sh
#
# Install XFCE Desktop & SLIM theme for OS108
#
mkdir /root/repo
cp /cdrom/OS108/* /root/repo
pkg_add -v /root/repo/pkg_install-20200701.tgz
pkg_add -v /root/repo/pkgin-20.8.0.tgz
rm /usr/pkg/etc/pkgin/repositories.conf
cp /root/repo/repositories_XFCE.conf /usr/pkg/etc/pkgin/repositories.conf
pkgin update
pkgin -y install nano sudo fam vlc xfce4 xfce4-extras wpa_gui libreoffice slim firefox-80.0.1nb1 bash
rm /usr/pkg/etc/pkgin/repositories.conf
cp /root/repo/repositories.conf /usr/pkg/etc/pkgin/
echo dbus=YES >> /etc/rc.conf
echo famd=YES >> /etc/rc.conf
echo rpcbind=YES >> /etc/rc.conf
echo slim=YES >> /etc/rc.conf
echo ipv6addrctl=YES >> /etc/rc.conf
echo ipv6addrctl_policy=ipv4_prefer >> /etc/rc.conf
cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/slim /etc/rc.d
visudo -c -q -f /root/repo/mysudo && cp /root/repo/mysudo /usr/pkg/etc/sudoers.d && chmod 600 /usr/pkg/etc/sudoers.d/mysudo
groupinfo wheel >> /root/users.list
sed -n '/^members[[:blank:]]*/{ s///; s/,[[:blank:]]/,/g; y/,/\n/; p; }' /root/users.list >> /root/final.list
USERS=`cat /root/final.list`
for user in ${USERS}; do

	if [ ${user} = root ] ; then
		echo skip setting root
	else 
		echo exec ck-launch-session dbus-launch --exit-with-session xfce4-session >> /home/${user}/.xinitrc
		mkdir /home/${user}/.icons/
		mkdir /home/${user}/.themes/
		cp /root/repo/01-McMojave-circle.tar.xz /home/${user}/.icons/
		cp /root/repo/Mojave-dark.tar.xz /home/${user}/.themes/
		cd /home/${user}/.icons/		
		tar -xf 01-McMojave-circle.tar.xz
		cp /root/repo/start-here.svg /home/${user}/.icons/McMojave-circle-dark/places/16/
		cd /home/${user}/.themes/		
		tar -xf Mojave-dark.tar.xz
		chown ${user} /home/${user}/.themes/Mojave-dark
		chown ${user} /home/${user}/.icons/McMojave-circle-dark
		mkdir /home/${user}/.config/
		mkdir /home/${user}/.config/xfce4/
		mkdir /home/${user}/.config/xfce4/xfconf/
		mkdir /home/${user}/.config/xfce4/xfconf/xfce-perchannel-xml/
		mkdir /home/${user}/.config/xfce4/panel/
		cp /root/repo/xfce4-panel.xml /home/${user}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
		cp /root/repo/xsettings.xml /home/${user}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
		cp /root/repo/xfce4-notifyd.xml /home/${user}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-notifyd.xml
		cp /root/repo/xfwm4.xml /home/${user}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
		cp /root/repo/xfce4-panel.xml /usr/pkg/etc/xdg/xfce4/panel/default.xml
		cp /root/repo/whiskermenu-7.rc /home/${user}/.config/xfce4/panel/whiskermenu-7.rc
		cp /root/repo/start-here.svg /home/start-here.svg
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

rm /root/users.list
rm /root/final.list
rm /usr/pkg/etc/sudoers.d/mysudo
visudo -c -q -f /root/repo/mysudofinal && cp /root/repo/mysudofinal /usr/pkg/etc/sudoers.d/mysudo && chmod 600 /usr/pkg/etc/sudoers.d/mysudo
sysctl -w kern.defcorename=/tmp/%n.core
rm -rf /root/repo
shutdown -r now

