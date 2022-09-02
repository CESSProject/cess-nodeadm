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
    local cgen_image=(`docker images | grep '^\b'cesslab/config-gen'\b ' | grep 'latest'`)
    cgen_image=${cgen_image[2]}
    local cgen_version=$(docker run --rm cesslab/config-gen version)
    printf "Docker images:\n"
    printf "  Config-gen: ${cgen_version} ${cgen_image}\n"

    if [ x"$mode" == x"authority" ]; then
        local chain_image=(`docker images | grep '^\b'cesslab/cess-chain'\b ' | grep 'latest'`)
        chain_image=${chain_image[2]}
        local chain_version=$(docker run --rm cesslab/cess-chain ./cess-node --version)
        printf "  Chain: ${chain_version} ${chain_image}\n"
        local sche_image=(`docker images | grep '^\b'cesslab/cess-scheduler'\b ' | grep 'latest'`)
        sche_image=${sche_image[2]}
        local sche_version=$(docker run --rm cesslab/cess-scheduler ./cess-scheduler version)
        printf "  Scheduler: ${sche_version} ${sche_image}\n"
    elif [ x"$mode" == x"storage" ]; then
        local bucket_image=(`docker images | grep '^\b'cesslab/cess-bucket'\b ' | grep 'latest'`)
        bucket_image=${bucket_image[2]}
        local bucket_version=$(docker run --rm cesslab/cess-bucket ./cess-bucket version)
        printf "  Bucket: $bucket_version ${bucket_image}\n"
    elif [ x"$mode" == x"watcher" ]; then
        local chain_image=(`docker images | grep '^\b'cesslab/cess-chain'\b ' | grep 'latest'`)
        chain_image=${chain_image[2]}
        local chain_version=$(docker run --rm cesslab/cess-chain ./cess-node --version)
        printf "  Chain: ${chain_version} ${chain_image}\n"
    fi
}
