#!/bin/sh

# =========== sources update

# apt-get update
apt-get autoremove -y


if ! grep --quiet '^deb' /etc/apt/sources.list.d/webupd8team-java-trusty.list; then
    apt-get install software-properties-common -y
    apt-get install python-software-properties -y
    add-apt-repository ppa:webupd8team/java -y
    apt-get update
fi


echo "Sources updated"
