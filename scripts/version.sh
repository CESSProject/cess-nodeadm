#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh

version() {
    printf "Node mode: ${mode}\n"
    printf "Profile: ${profile}\n"
    printf "nodeadm version: ${nodeadm_version}\n"
    inner_docker_version

    if [[ -f $config_file ]]; then
        local ss=$(yq eval '.node.noWatchContainers //[] | join(", ")' $config_file)
        if [[ -n ${ss// /} ]]; then
            log_info "No auto upgrade service(s): $ss"
        fi
    fi
}

inner_docker_version() {
    printf "Docker images:\n"
    show_version "config-gen" "cesslab/config-gen" "version"

    show_version "chain" "cesslab/cess-chain" "--version"
    if [ x"$mode" == x"authority" ]; then
        show_version "cifrost" "cesslab/cifrost" "--version"
        show_version "ceseal" "cesslab/ceseal" '-c "EXTRA_OPTS=version ./start.sh" 2>&1 | tail -n 2 | head -n 1' "--device /dev/sgx_enclave --device /dev/sgx_provision --entrypoint /bin/bash -e SLEEP_BEFORE_START=0"
    elif [ x"$mode" == x"storage" ]; then
        show_version "miner" "cesslab/cess-miner" "version"
    fi
}

function show_version() {
    local prog_name=$1
    local image_name=$2
    local image_tag=$profile
    local version_cmd=$3
    local extra_docker_opts=$4
    local image_hash=($(docker images | grep '^\b'$image_name'\b ' | grep $image_tag))
    image_hash=${image_hash[2]}
    local cmd=$(echo docker run --rm $extra_docker_opts $image_name:$image_tag $version_cmd)
    local version=$(eval "$cmd")
    printf "  $prog_name: ${version} ${image_hash}\n"
}
