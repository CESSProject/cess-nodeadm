#!/bin/bash

nodeadm_version="v0.1.0"
aliyun_address="region.cn-hangzhou.aliyuncs.com"

base_dir=/opt/cess/nodeadm
script_dir=$base_dir/scripts
config_file=$base_dir/config.yaml
build_dir=$base_dir/build
compose_yaml=$build_dir/docker-compose.yaml

function echo_c()
{
    printf "\033[0;$1m$2\033[0m\n"
}

function log_info()
{
    echo_c 33 "$1"
}

function log_success()
{
    echo_c 32 "$1"
}

function log_err()
{
    echo_c 35 "[ERROR] $1"
}

function upgrade_docker_image()
{
    local image_name=$1
    local image_tag="latest"
    if [ x"$2" != x"" ]; then
        image_tag=$2
    fi

    local old_image=(`docker images | grep '^\b'cesslab/$image_name'\b ' | grep 'latest'`)
    old_image=${old_image[2]}

    local region="`yq eval ".node.region" $config_file`"
    local docker_org="cesslab"
    if [ x"$region" == x"cn" ]; then
       docker_org=$aliyun_address/$docker_org
    fi

    local res=0
    docker pull $docker_org/$image_name:$image_tag
    res=$(($?|$res))
    docker tag $docker_org/$image_name:$image_tag cesslab/$image_name

    if [ $res -ne 0 ]; then
        log_err "Download docker image $image_name:$image_tag failed"
        return 1
    fi

    local new_image=(`docker images | grep '^\b'cesslab/$image_name'\b ' | grep 'latest'`)
    new_image=${new_image[2]}
    if [ x"$old_image" = x"$new_image" ]; then
        log_info "The current docker image $image_name ($old_image) is already the latest"
        return 1
    fi
    
    log_info "The docker image of $image_name is changed from $old_image to $new_image"

    return 0
}

check_port() {
    local port=$1
    local grep_port=`netstat -tlpn | grep "\b$port\b"`
    if [ -n "$grep_port" ]; then
        log_err "please make sure port $port is not occupied"
        return 1
    fi
}

## 0 for running, 2 for error, 1 for stop
check_docker_status()
{
    local exist=`docker inspect --format '{{.State.Running}}' $1 2>/dev/null`
    if [ x"${exist}" == x"true" ]; then
        return 0
    elif [ "${exist}" == "false" ]; then
        return 2
    else
        return 1
    fi
}

## rnd=$(rand 1 50)
rand()
{
    min=$1
    max=$(($2-$min+1))
    num=$(date +%s%N)
    echo $(($num%$max+$min))
}

ensure_root()
{
    if [ $(id -u) -ne 0 ]; then
        log_err "Please run with sudo!"
        exit 1
    fi
}

PM=""
DISTRO=""

get_distro_name()
{
    if grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt'
    else
        log_err 'unsupport linux distro'
        return 1
    fi
    return 0
}

SGX_DRIVER=""
SGX_DEVICES=()
ensure_installed_sgx_driver()
{
    local info=""
    local ret=0
    if [ -L /dev/sgx/enclave ] && [ -L /dev/sgx/provision ] && [ -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx_enclave" "/dev/sgx_provision")
        info="Your device exists: /dev/sgx/enclave /dev/sgx/provision /dev/sgx_enclave /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ -L /dev/sgx/provision ] && [ -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx_enclave" "/dev/sgx_provision")
        info="Your device exists: /dev/sgx/provision /dev/sgx_enclave /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ ! -L /dev/sgx/provision ] && [ -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx_enclave" "/dev/sgx_provision")
        info="Your device exists: /dev/sgx_enclave /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ ! -L /dev/sgx/provision ] && [ ! -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx_provision")
        info="Your device exists: /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ ! -L /dev/sgx/provision ] && [ ! -c /dev/sgx_enclave ] && [ ! -c /dev/sgx_provision ] && [ -c /dev/isgx ]; then
        SGX_DRIVER="isgx"
        SGX_DEVICES=("/dev/isgx")
        info="Your device exists: /dev/isgx is related to the isgx driver"
    else
        info="The DCAP/isgx driver file was not found, please check the driver installation logs!"
        ret=1
    fi
    if [ x"$1" == x"" ]; then
        log_info "$info"
        if [ $ret -eq 0 ]; then
            log_info "Your machine's SGX driver is: $SGX_DRIVER"
        fi
    fi
    return $ret
}