#! /bin/sh
#
# copy necessary binary packages into setupliveimage per packages-YYYYMMDD.list
#

PACKAGES=`cat list/packages-20181211.list`

for pkg in ${PACKAGES}; do
	echo downloading ${pkg}.tgz
	pkgin -d -y install ${pkg}
	
        done

echo Done!
