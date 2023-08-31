#!/bin/bash

install_dir=/opt/cess/nodeadm
compose_yaml=$install_dir/build/docker-compose.yaml
bin_file=/usr/bin/cess

if [ $(id -u) -ne 0 ]; then
    echo "Please run with sudo!"
    exit 1
fi

if [ -f "$compose_yaml" ]; then
    docker compose -f $compose_yaml rm -sf
    docker compose -f $compose_yaml down -v --remove-orphans --rmi all
fi

podr2_key=/opt/cess/authority/kaleido/key/encrypted/podr2_key
if [[ -f $podr2_key ]]; then
    rm $podr2_key
fi

if [ -f "$bin_file" ]; then    
    rm /usr/bin/cess
fi

rm -rf $install_dir
