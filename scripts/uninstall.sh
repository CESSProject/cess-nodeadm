#!/bin/bash

install_dir=/opt/cess/nodeadm
bin_file=/usr/bin/cess

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

if [ -f "$bin_file" ]; then
    cess stop
    rm /usr/bin/cess
fi

rm -rf $install_dir
