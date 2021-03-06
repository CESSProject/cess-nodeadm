#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh

version()
{
    printf "Node mode: ${mode}\n"
    printf "nodeadm version: ${nodeadm_version}\n"
    inner_docker_version
}

inner_docker_version()
{
    local cgen_image=(`docker images | grep '^\b'cesslab/config-gen'\b ' | grep 'latest'`)
    cgen_image=${cgen_image[2]}
    printf "Docker images:\n"
    printf "  Config-gen: ${cgen_image}\n"

    if [ x"$mode" == x"authority" ]; then
        local chain_image=(`docker images | grep '^\b'cesslab/cess-chain'\b ' | grep 'latest'`)
        chain_image=${chain_image[2]}
        local sche_image=(`docker images | grep '^\b'cesslab/cess-scheduler'\b ' | grep 'latest'`)
        sche_image=${sche_image[2]}
        printf "  Chain: ${chain_image}\n"
        printf "  Scheduler: ${sche_image}\n"
    elif [ x"$mode" == x"storage" ]; then
        local bucket_image=(`docker images | grep '^\b'cesslab/cess-bucket'\b ' | grep 'latest'`)
        bucket_image=${bucket_image[2]}
        printf "  Bucket: ${bucket_image}\n"
    elif [ x"$mode" == x"watcher" ]; then
        local chain_image=(`docker images | grep '^\b'cesslab/cess-chain'\b ' | grep 'latest'`)
        chain_image=${chain_image[2]}
        printf "  Chain: ${chain_image}\n"
    fi
}
