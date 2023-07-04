#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh

version()
{
    printf "Node mode: ${mode}\n"
    printf "Profile: ${profile}\n"
    printf "nodeadm version: ${nodeadm_version}\n"
    inner_docker_version
}

inner_docker_version()
{
    printf "Docker images:\n"
    show_version "Config-gen" "cesslab/config-gen" "version"

    show_version "Chain" "cesslab/cess-chain" "./cess-node --version"
    if [ x"$mode" == x"authority" ]; then
        show_version "Kaleido" "cesslab/kaleido-rotator" "--version"
        show_version "Kaleido" "cesslab/kaleido" "--version" "--entrypoint ./target/release/kaleido"
    elif [ x"$mode" == x"storage" ]; then
        show_version "Bucket" "cesslab/cess-bucket" "./cess-bucket version"
    fi
}

function show_version() {
    local prog_name=$1
    local image_name=$2
    local image_tag=$profile
    local version_cmd=$3
    local extra_docker_opts=$4
    local image_hash=(`docker images | grep '^\b'$image_name'\b ' | grep $image_tag`)
    image_hash=${image_hash[2]}
    local version=$(docker run --rm $extra_docker_opts $image_name:$image_tag $version_cmd)
    printf "  $prog_name: ${version} ${image_hash}\n"
}