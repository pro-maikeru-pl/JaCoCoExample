#!/bin/sh

apt-get update
apt-get autoremove -y

touch /etc/apt/sources.list.d/webupd8team-java-trusty.list
if ! grep --quiet '^deb' /etc/apt/sources.list.d/webupd8team-java-trusty.list; then
    apt-get install language-pack-pl -y
    apt-get install software-properties-common -y
    apt-get install python-software-properties -y
    add-apt-repository ppa:webupd8team/java -y
    apt-get update
    echo "Sources updated"


    echo 'debconf shared/accepted-oracle-license-v1-1 select true' | debconf-set-selections
    echo 'debconf shared/accepted-oracle-license-v1-1 seen true' | debconf-set-selections

    # this is hack, but this package downloads additional files and the connection can break several times
    # luckily, each time it resumes failed download, so calling it two times as preparation should be enough
    echo "Trying to download oracle java installer, pe patient as it can take significant amount of time..."
    apt-get install oracle-java7-installer -y
    echo "Still downloading, be patient... :)"
    apt-get install oracle-java7-installer -y
fi