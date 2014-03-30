#!/bin/sh
#jinstall - Command line script to easily add new java directories to
#'alternatives'. This sets the java as default, and you can switch your
#default java with update-java-alternatives
#
#Copyright 2012 Bruce.Ingalls at gmail & Alin Andrei <webupd8@gmail.com>
#GPL v3 Affero license at http://www.gnu.org/
#Downloads & discussion at http://www.webupd8.org/
#Tested on Ubuntu Oneiric; should require few changes for other modern Unix systems
#Currently tested only with JDK, not JRE.
# Not fully internationalized, including japanese man pages

set -e

. /usr/share/debconf/confmodule


### Variables
VER='0.7'

# Folders
J_INSTALL_DIR=/usr/lib/jvm/java-7-oracle
OLDDIR=/usr/lib/oracle-jdk7-installer-unpackdir
NEWDIR=/var/cache/oracle-jdk7-installer

# Must be modified for each release
JAVA_VERSION=7u51
J_DIR=jdk1.7.0_51

# Filenames and checksums
case $(dpkg --print-architecture) in
'i386'|'i586'|'i686')
	arch=i386; dld=i586
	# Must be modified for each release
	SHA256SUM_TGZ="b3a2965e44446e476f4e27f7ea13a503a91403ac80bcd71693ad2f84baff42cf"
	;;
'amd64')
	arch=amd64; dld=x64
	# Must be modified for each release
	SHA256SUM_TGZ="77367c3ef36e0930bf3089fb41824f4b8cf55dcc8f43cce0868f7687a474f55c"
	;;
arm*)
	arch=arm
	if [ `uname -m` = "armv7l" ] || [ `uname -m` = "armv6l" ]; then
		if [ -x /usr/bin/readelf ] ; then
			HARDFLOAT=`readelf -A /proc/self/exe | grep Tag_ABI_VFP_args`
			if [ -z "$HARDFLOAT" ]; then
				# Softfloat
				dld='arm-vfp-sflt'
				# Must be modified for each release
				SHA256SUM_TGZ="75b776dc71e62e5440cf619bd7cf7022fa4e82888ca408bf496413e2bcfe0bbe"
			else
				# Hardfloat
				dld='arm-vfp-hflt'
				# Must be modified for each release
				SHA256SUM_TGZ="47273843454755d1bdd3b91ec97c42b1bcdae01af6e42c38413c3d0ff630557a"
			fi
		fi
	else
		echo "Oracle JDK 7 only supports ARM v6/v7."
		arch=''
	fi
	;;
*)
	echo "Please report to author unsupported platform '`uname -m`'.";
	echo "Proceeding without web browser plugin support";
	arch='';
esac
FILENAME=jdk-${JAVA_VERSION}-linux-${dld}.tar.gz
for JAVA_VERSION_OLD in `seq 1 50`; do #must be modified for each release ("1 3" for 7u4; "1 4" for 7u5, etc)
	FILENAMES_OLD="jdk-7u${JAVA_VERSION_OLD}-linux-${dld}.tar.gz $FILENAMES_OLD"
done

# Must be modified for each release!!!
PARTNER_URL=http://download.oracle.com/otn-pub/java/jdk/7u51-b13/$FILENAME

### Functions
fp_exit_with_error() {
	echo $1
	echo "Oracle JDK 7 is NOT installed."
	db_fset oracle-java7-installer/local seen false
	exit 1
}

fp_download_and_unpack() {
	cd /var/cache/oracle-jdk7-installer

	db_get oracle-java7-installer/local
	if [ -d "$RET" -a -f "$RET"/$FILENAME ]; then
		echo "Installing from local file $RET/$FILENAME"
		cp -f -p "$RET"/$FILENAME ${FILENAME}_TEMP
		mv -f ${FILENAME}_TEMP $FILENAME
	else # no local file
		# use apt proxy
		APT_PROXIES=$(apt-config shell \
		http_proxy Acquire::http::Proxy \
		https_proxy Acquire::https::Proxy \
		ftp_proxy Acquire::ftp::Proxy \
		dl_direct Acquire::http::Proxy::download.oracle.com \
		)

		[ -n "$APT_PROXIES" ] && eval export $APT_PROXIES

		if [ "$dl_direct" = "DIRECT" ]; then
			unset http_proxy
			unset https_proxy
			unset ftp_proxy
		fi

		# setting wget options
		:> wgetrc
		echo "noclobber = off" >> wgetrc
		echo "dir_prefix = ." >> wgetrc
		echo "dirstruct = off" >> wgetrc
		echo "verbose = on" >> wgetrc
		echo "progress = dot:mega" >> wgetrc
		echo "tries = 2" >> wgetrc

		# downloading jdk7
		echo "Downloading Oracle Java 7..."
		WGETRC=wgetrc wget --continue --no-check-certificate -O $FILENAME --header "Cookie: oraclelicense=a" $PARTNER_URL \
			|| fp_exit_with_error "download failed"
		echo "Download done."
	fi # end if local file

	# Removing outdated cached downloads
	echo "Removing outdated cached downloads..."
	rm -vf $FILENAMES_OLD

	# Verify SHA256 checksum of (copied or downloaded) tarball
	rm -rf jdk*/
        echo "$SHA256SUM_TGZ  $FILENAME" | sha256sum -c > /dev/null 2>&1 \
		|| fp_exit_with_error "sha256sum mismatch $FILENAME"

	# Unpacking and checking the plugin
	tar xzf $FILENAME || fp_exit_with_error "cannot unpack jdk7"
}

safe_move() {
	[ ! -f $OLDDIR/$1 ] || [ -f $NEWDIR/$1 ] || mv $OLDDIR/$1 $NEWDIR/$1 2> /dev/null || true
	[ ! -f $OLDDIR/$1 ] || [ ! -f $NEWDIR/$1 ] || rm -f $OLDDIR/$1 2> /dev/null || true
}

### Main

# Create dirs
mkdir -p /var/cache/oracle-jdk7-installer /usr/lib/jvm /usr/lib/oracle-jdk7-installer-unpackdir
# Without this, an error is displayed if the folder doesn't exist:
mkdir -p /usr/lib/mozilla/plugins/

fp_download_and_unpack

# Copy JDK to the right dir
mv $J_DIR java-7-oracle
rm -rf /usr/lib/jvm/java-7-oracle
cp -rf java-7-oracle /usr/lib/jvm/

# There's no javaws on arm
if [ ! $arch = "arm" ]; then
# Install javaws-wrapper.sh
	mv $J_INSTALL_DIR/jre/bin/javaws $J_INSTALL_DIR/jre/bin/javaws.real
	install -m 755 javaws-wrapper.sh $J_INSTALL_DIR/jre/bin/javaws
fi

# Install jar.binfmt
install -m 755 jar.binfmt $J_INSTALL_DIR/jre/lib/jar.binfmt

# Clean up
rm -rf java-7-oracle

# To add when an older version exists:
# safe_move jdk-7u2-linux-x64.tar.gz #must be modified for each release
# safe_move jdk-7u2-linux-i586.tar.gz #must be modified for each release
# Remove previous versions, if they exist
rmdir $OLDDIR 2> /dev/null || true

db_fset oracle-java7-installer/local seen false

# This step is optional, recommended, and affects code below.
ls $J_INSTALL_DIR/man/man1/*.1 >/dev/null 2>&1 && \
  gzip -9 $J_INSTALL_DIR/man/man1/*.1 >/dev/null 2>&1

# Increment highest version by 1.
# Also assumes all Java helper programs (javaws, jcontrol, etc) at same version as java.
# These helpers should be slaves, or in the same path as java; thus, a reasonable assumption.
LATEST=1
LATEST=$((`LANG=C update-alternatives --display java | grep ^/ | sed -e 's/.* //g' | sort -n | tail -1`+1))

# Create .java-7-oracle.jinfo file header:
[ -e /usr/lib/jvm/.java-7-oracle.jinfo ] && rm -f /usr/lib/jvm/.java-7-oracle.jinfo
echo "name=java-7-oracle
alias=java-7-oracle
priority=$LATEST
section=non-free
" > /usr/lib/jvm/.java-7-oracle.jinfo

# Link JRE files
for f in $J_INSTALL_DIR/jre/bin/*; do
	name=`basename $f`;
	if [ ! -f "/usr/bin/$name" -o -L "/usr/bin/$name" ]; then
		# Some files, like jvisualvm might not be links
		if [ -f "$J_INSTALL_DIR/man/man1/$name.1.gz" ]; then
			if [ ! $arch = "arm" ]; then
				update-alternatives --install /usr/bin/$name $name $J_INSTALL_DIR/jre/bin/$name $LATEST \
					--slave /usr/share/man/man1/$name.1.gz $name.1.gz $J_INSTALL_DIR/man/man1/$name.1.gz
				echo "jre $name $J_INSTALL_DIR/jre/bin/$name" >> /usr/lib/jvm/.java-7-oracle.jinfo
			else
				# There's no jmc, javaws or jvisualvm on arm
				[ ! $name = "jmc" ] && [ ! $name = "javaws" ] && [ ! $name = "jvisualvm" ] && update-alternatives --install /usr/bin/$name \
					$name $J_INSTALL_DIR/jre/bin/$name $LATEST --slave /usr/share/man/man1/$name.1.gz $name.1.gz \
					$J_INSTALL_DIR/man/man1/$name.1.gz
				[ ! $name = "jmc" ] && [ ! $name = "javaws" ] && [ ! $name = "jvisualvm" ] && echo \
					"jre $name $J_INSTALL_DIR/jre/bin/$name" >> /usr/lib/jvm/.java-7-oracle.jinfo
			fi
		else
			# No man pages available
			#[ ! $name = "javaws.real" ] = skip javaws.real
				[ ! $name = "javaws.real" ] && update-alternatives --install /usr/bin/$name $name $J_INSTALL_DIR/jre/bin/$name $LATEST
				[ ! $name = "javaws.real" ] && echo "jre $name $J_INSTALL_DIR/jre/bin/$name" >> /usr/lib/jvm/.java-7-oracle.jinfo
		fi
	fi
done

# Link JRE not in jre/bin
[ -f $J_INSTALL_DIR/jre/lib/jexec ] && \
	update-alternatives --install /usr/bin/jexec jexec $J_INSTALL_DIR/jre/lib/jexec $LATEST \
		--slave /usr/share/binfmts/jar jexec-binfmt $J_INSTALL_DIR/jre/lib/jar.binfmt && \
		echo "jre jexec $J_INSTALL_DIR/jre/lib/jexec" >> /usr/lib/jvm/.java-7-oracle.jinfo

# This will issue ignorable warnings for alternatives that are not part of a group
# Link JDK files with/without man pages
if [ -d "$J_INSTALL_DIR/man/man1" ]; then
	for f in $J_INSTALL_DIR/man/man1/*; do
		name=`basename $f .1.gz`
		# Some files, like jvisualvm might not be links.
		# Further assume this for corresponding man page
		if [ ! -f "/usr/bin/$name" -o -L "/usr/bin/$name" ]; then
			if [ ! -f "$J_INSTALL_DIR/man/man1/$name.1.gz" ]; then
				# Handle any legacy uncompressed pages
				name=`basename $f .1`
			fi
			if [ ! -e $J_INSTALL_DIR/jre/bin/$name ]; then
				# Don't link already linked JRE files
				if [ ! $arch = "arm" ]; then
					update-alternatives --install /usr/bin/$name $name $J_INSTALL_DIR/bin/$name $LATEST \
						--slave /usr/share/man/man1/$name.1.gz $name.1.gz $J_INSTALL_DIR/man/man1/$name.1.gz
					echo "jdk $name $J_INSTALL_DIR/bin/$name" >> /usr/lib/jvm/.java-7-oracle.jinfo
				else
					# There's no jmc, javaws or jvisualvm on arm
					[ ! $name = "jmc" ] && [ ! $name = "javaws" ] && [ ! $name = "jvisualvm" ] && update-alternatives --install \
						/usr/bin/$name $name $J_INSTALL_DIR/bin/$name $LATEST --slave /usr/share/man/man1/$name.1.gz \
						$name.1.gz $J_INSTALL_DIR/man/man1/$name.1.gz
					[ ! $name = "jmc" ] && [ ! $name = "javaws" ] && [ ! $name = "jvisualvm" ] && \
						echo "jdk $name $J_INSTALL_DIR/bin/$name" >> /usr/lib/jvm/.java-7-oracle.jinfo
				fi
			fi
		fi
	done
else  #no man pages available
	for f in $J_INSTALL_DIR/bin/*; do
		name=`basename $f`;
		if [ ! -f "/usr/bin/$name" -o -L "/usr/bin/$name" ]; then
			# Some files, like jvisualvm might not be links
			if [ ! -e $J_INSTALL_DIR/jre/bin/$name ]; then
				# Don't link already linked JRE files
					update-alternatives --install /usr/bin/$name $name $J_INSTALL_DIR/bin/$name $LATEST
					echo "jdk $name $J_INSTALL_DIR/bin/$name" >> /usr/lib/jvm/.java-7-oracle.jinfo
			fi
		fi
	done
fi

# Hide javaws and jvisualvm desktop files on arm since these files don't exist on this architecture
if [ $arch = "arm" ]; then
echo "NoDisplay=true" >> /usr/share/applications/JB-javaws.desktop
echo "NoDisplay=true" >> /usr/share/applications/JB-jvisualvm.desktop
fi

# Register binfmt; ignore errors, the alternative may already be registered by another JRE.
which update-binfmts >/dev/null && [ -r /usr/share/binfmts/jar ] && \
	update-binfmts --package oracle-java7 --import jar || true
echo "Oracle JDK 7 installed"

# Install Firefox (and compatible) plugin. $arch will be empty for unknown platform
# No plugin for arm architecture yet
[ -f $J_INSTALL_DIR/jre/lib/$arch/libnpjp2.so ] && \
	update-alternatives --install /usr/lib/mozilla/plugins/libjavaplugin.so mozilla-javaplugin.so $J_INSTALL_DIR/jre/lib/$arch/libnpjp2.so $LATEST && \
	echo "plugin mozilla-javaplugin.so $J_INSTALL_DIR/jre/lib/$arch/libnpjp2.so" >> /usr/lib/jvm/.java-7-oracle.jinfo && \
echo "Oracle JRE 7 browser plugin installed"

# Automatically added by dh_installmime
if [ "$1" = "configure" ] && [ -x "`which update-mime-database 2>/dev/null`" ]; then
	update-mime-database /usr/share/mime
fi
# End automatically added section


exit 0

# vim: ts=2 sw=2
