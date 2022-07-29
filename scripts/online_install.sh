#!/bin/bash

version=$1
shift

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

echo "downloading cess-nodeadm-v$version from github"
wget -q https://github.com/CESSProject/cess-nodeadm/archive/v$version.tar.gz
if [ $? -ne 0 ]; then
    echo "Download cess-nodeadm-v$version.tar.gz failed"
    exit 1
fi

tar -xf v$version.tar.gz
if [ $? -ne 0 ]; then
    echo "Unzip cess-nodeadm-v$version.tar.gz failed"
    rm v$version.tar.gz
    exit 1
fi

echo "start install cess-nodeadm-v$version"
./cess-nodeadm-$version/install.sh $@
if [ $? -ne 0 ]; then
    echo "Install cess-nodeadm $version failed"
    rm v$version.tar.gz
    rm -rf cess-nodeadm-$version
    exit 1
fi

rm v$version.tar.gz
rm -rf cess-nodeadm-$version
exit 0
