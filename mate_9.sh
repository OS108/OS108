#! /bin/sh
#
# Install MATE Desktop & SLIM theme for OS108
#
cp /cdrom/amd64/binary/sets/pkgs/pkgin-0.15.0nb1.tgz /root
cp /cdrom/amd64/binary/sets/pkgs/pkg_install-20191008nb1.tgz /root
pkg_add -v /root/pkg_install-20191008nb1.tgz
pkg_add -v /root/pkgin-0.15.0nb1.tgz
mkdir /root/repo
cp /cdrom/amd64/binary/sets/pkgs/* /root/repo
rm /usr/pkg/etc/pkgin/repositories.conf
cp /cdrom/amd64/binary/sets/pkgs/repositories_MATE.conf /usr/pkg/etc/pkgin/repositories.conf
pkgin update
pkgin -y install nano sudo mate fam vlc mate-system-monitor firefox-73.0 wpa_gui libreoffice slim bash gimp
rm /usr/pkg/etc/pkgin/repositories.conf
cp /cdrom/amd64/binary/sets/pkgs/repositories.conf /usr/pkg/etc/pkgin/
echo dbus=YES >> /etc/rc.conf
echo famd=YES >> /etc/rc.conf
echo rpcbind=YES >> /etc/rc.conf
echo slim=YES >> /etc/rc.conf
echo ipv6addrctl=YES >> /etc/rc.conf
echo ipv6addrctl_policy=ipv4_prefer >> /etc/rc.conf
cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
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
		cp /root/repo/dconf.dump.out /home/${user}/
		chown ${user} /home/${user}/dconf.dump.out
		sudo su -l ${user} -c "dbus-launch dconf load / < /home/${user}/dconf.dump.out"
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
mkdir /home/homepage-master
cp /root/repo/README.md /home/homepage-master
cp /root/repo/favicon.png /home/homepage-master
cp /root/repo/index.html /home/homepage-master
cp /root/repo/styles.css /home/homepage-master
cp /root/repo/firefox.js /usr/pkg/lib/firefox/browser/defaults/preferences/
rm -rf /root/repo
rm /root/users.list
rm /root/final.list
rm /root/pkgin-0.15.0nb1.tgz
rm /root/pkg_install-20191008nb1.tgz
rm /usr/pkg/etc/sudoers.d/mysudo
visudo -c -q -f /cdrom/amd64/binary/sets/pkgs/mysudofinal && cp /cdrom/amd64/binary/sets/pkgs/mysudofinal /usr/pkg/etc/sudoers.d/mysudo && chmod 600 /usr/pkg/etc/sudoers.d/mysudo
sysctl -w kern.defcorename=/tmp/%n.core
shutdown -r now
