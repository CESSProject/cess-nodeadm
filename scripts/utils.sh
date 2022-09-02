#!/bin/bash

nodeadm_version="v0.1.1"
aliyun_address="region.cn-hangzhou.aliyuncs.com"

base_dir=/opt/cess/nodeadm
script_dir=$base_dir/scripts
config_file=$base_dir/config.yaml
build_dir=$base_dir/build
compose_yaml=$build_dir/docker-compose.yaml
default_image_tag="latest"
profile="prod"

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

# print the right color for each level
#
# Arguments:
# 1:  level
function msg_color {
    priority=$1
    if [[ $priority == "fatal" ]] ; then
        echo -e "\033[31m"
    elif [[ $priority == "error" ]] ; then
        echo -e "\033[34m"
    elif [[ $priority == "warning" ]] ; then
        echo -e "\033[35m"
    elif [[ $priority == "info" ]] ; then
        echo -e "\033[36m"
    elif [[ $priority == "debug" ]] ; then
        echo -e "\033[37m"
    elif [[ $priority == "default" ]] ; then
        echo -e "\033[00m"
    else
        echo -e "\033[32m";
    fi
}

function upgrade_docker_image()
{
    local image_name=$1
    local image_tag=$default_image_tag
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
        SGX_DEVICES=("/dev/sgx/enclave" "/dev/sgx/provision")
        info="Your device exists: /dev/sgx/enclave /dev/sgx/provision /dev/sgx_enclave /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ -L /dev/sgx/provision ] && [ -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx/enclave" "/dev/sgx/provision")
        info="Your device exists: /dev/sgx/provision /dev/sgx_enclave /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ ! -L /dev/sgx/provision ] && [ -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx/enclave" "/dev/sgx/provision")
        info="Your device exists: /dev/sgx_enclave /dev/sgx_provision is related to the DCAP driver"
    elif [ ! -L /dev/sgx/enclave ] && [ ! -L /dev/sgx/provision ] && [ ! -c /dev/sgx_enclave ] && [ -c /dev/sgx_provision ] && [ ! -c /dev/isgx ]; then
        SGX_DRIVER="dcap"
        SGX_DEVICES=("/dev/sgx/provision")
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

oot_driver_found=false

function check_oot_driver {
    if [[ ! -e /sys/module/isgx/version ]] ; then
        oot_driver_found=false
    else
        oot_driver_found=true
        echo "SGX-driver already installed."
        if [[ ! -e /dev/isgx ]] ; then
            log_err "SGX driver is installed but no SGX device - SGX not enabled?"
            exit 1
        fi
    fi
}

dcap_driver_found=false

function check_dcap_driver {
    if [[ ! -e /sys/module/intel_sgx/version ]] ; then
        dcap_driver_found=false
    else
        dcap_driver_found=true
        echo "DCAP SGX-driver already installed."
        if [[ ! -e /dev/sgx ]] ; then
            log_err "DCAP SGX driver is installed but no SGX device - SGX not enabled?"
            exit 1
        fi
    fi
}

install_dcap=0

function check_sgx {    
    msg_color "info"
    echo -n "INFO: Checking CPU capabilities..."
    msg_color "default"

    local cpuid_cmd=$(which cpuid || true)

    if [ -z $cpuid_cmd ]; then
        msg_color "info"
        echo -n "INFO: 'cpuid' not found! Installing CPUID... "

        sudo apt-get update > /dev/null && \
        sudo apt-get install -y cpuid > /dev/null

        echo "Done!"
        msg_color "default"

        cpuid_cmd=$(which cpuid)
    fi

    local cpuid_leaf7_val=$($cpuid_cmd -r -1  | grep "$(printf '0x%08x 0x00:' "$((0x07))")" || true)
    local cpuid_leaf12_val=$($cpuid_cmd -r -1  | grep "$(printf '0x%08x 0x00:' "$((0x12))")" || true)

    local l7_ebx=$(echo $cpuid_leaf7_val | awk '{split($4,ebx,"="); print ebx[2]}')
    local l7_ecx=$(echo $cpuid_leaf7_val | awk '{split($5,ecx,"="); print ecx[2]}')

    local l12_eax=$(echo $cpuid_leaf12_val | awk '{split($3,eax,"="); print eax[2]}')

    local sgx="$((l7_ebx >> 2 & 1))"
    local dcap="$((l7_ecx >> 30 & 1))"

    if [[ $sgx != "1" ]]; then
        # SGX is not supported
        log_error "ERROR: SGX is not supported!"
        exit 1
    fi

    if [[ $dcap == "1" ]]; then
        # enable dcap
        install_dcap=1
    fi    
}

function set_profile()
{
    local to_set=$1
    if [ x"$to_set" == x"dev" ] || [ x"$to_set" == x"test" ] || [ x"$to_set" == x"prod" ]; then
        yq -i eval ".node.profile=\"$to_set\"" $config_file
        log_success "the profile set to $to_set"
        return 0
    fi
    log_err "invalid profile value"
    return 1
}

function load_profile()
{
    local p="`yq eval ".node.profile" $config_file`"
    if [ x"$p" == x"dev" ] || [ x"$p" == x"test" ] || [ x"$p" == x"prod" ]; then
        profile=$p
        if [ x"$p" == x"dev" ]; then
            default_image_tag="dev"
        fi
        return 0
    fi
    log_err "the profile: $p of config file is invalid, use default value: $profile"
    return 1
}