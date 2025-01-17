#!/bin/bash

nodeadm_version="v0.6.0"
aliyun_address="region.cn-hangzhou.aliyuncs.com"

base_dir=/opt/cess/nodeadm
script_dir=$base_dir/scripts
config_file=$base_dir/config.yaml
build_dir=$base_dir/build
compose_yaml=$build_dir/docker-compose.yaml
profile="testnet"

function echo_c() {
    printf "\033[0;$1m$2\033[0m\n"
}

function log_info() {
    echo_c 33 "$1"
}

function log_success() {
    echo_c 32 "$1"
}

function log_err() {
    echo_c 35 "[ERROR] $1" >&2
}

# print the right color for each level
#
# Arguments:
# 1:  level
function msg_color {
    priority=$1
    if [[ $priority == "fatal" ]]; then
        echo -e "\033[31m"
    elif [[ $priority == "error" ]]; then
        echo -e "\033[34m"
    elif [[ $priority == "warning" ]]; then
        echo -e "\033[35m"
    elif [[ $priority == "info" ]]; then
        echo -e "\033[36m"
    elif [[ $priority == "debug" ]]; then
        echo -e "\033[37m"
    elif [[ $priority == "default" ]]; then
        echo -e "\033[00m"
    else
        echo -e "\033[32m"
    fi
}

force_install() {
    if [ "$1" != "true" ]; then
        log_err "Can use --ignore-error to skip error and then install the dependencies manually"
        exit 1
    fi
}

check_port() {
    local port=$1
    local grep_port=$(netstat -tlpn | grep "\b$port\b")
    if [ -n "$grep_port" ]; then
        log_err "please make sure port $port is not occupied"
        return 1
    fi
}

## 0 for running, 2 for error, 1 for stop
check_docker_status() {
    local exist=$(docker inspect --format '{{.State.Running}}' $1 2>/dev/null)
    if [ x"${exist}" == x"true" ]; then
        return 0
    elif [ "${exist}" == "false" ]; then
        return 2
    else
        return 1
    fi
}

## rnd=$(rand 1 50)
rand() {
    min=$1
    max=$(($2 - $min + 1))
    num=$(date +%s%N)
    echo $(($num % $max + $min))
}

ensure_root() {
    if [ $(id -u) -ne 0 ]; then
        log_err "Please run with sudo!"
        exit 1
    fi
}

PM=""
DISTRO=""

get_distro_name() {
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

# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
add_docker_ubuntu_repo() {
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
}

# https://docs.docker.com/engine/install/centos/#set-up-the-repository
add_docker_centos_repo() {
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
}

function set_profile() {
    local to_set=$1
    if [ -z $to_set ]; then
        log_info "current profile: $profile"
        return 0
    fi
    if [ x"$to_set" == x"devnet" ] || [ x"$to_set" == x"testnet" ] || [ x"$to_set" == x"mainnet" ] || [ x"$to_set" == x"ownnet" ]; then
        yq -i eval ".node.profile=\"$to_set\"" $config_file
        log_success "the profile set to $to_set"
        return 0
    fi
    log_err "invalid profile value"
    return 1
}

function load_profile() {
    local p="$(yq eval ".node.profile" $config_file)"
    if [ x"$p" == x"devnet" ] || [ x"$p" == x"testnet" ] || [ x"$p" == x"mainnet" ] || [ x"$p" == x"ownnet" ]; then
        profile=$p
        return 0
    fi
    log_err "the profile: $p of config file is invalid, use default value: $profile"
    return 1
}

function command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# is_ver_a_ge_b compares two CalVer (YY.MM) version strings. returns 0 (success)
# if version A is newer or equal than version B, or 1 (fail) otherwise. Patch
# releases and pre-release (-alpha/-beta) are not taken into account
#
# examples:
#
# is_ver_a_ge_b 20.10 19.03 // 0 (success)
# is_ver_a_ge_b 20.10 20.10 // 0 (success)
# is_ver_a_ge_b 19.03 20.10 // 1 (fail)
function is_ver_a_ge_b() (
    set +x

    yy_a="$(echo "$1" | cut -d'.' -f1)"
    yy_b="$(echo "$2" | cut -d'.' -f1)"
    if [ "$yy_a" -lt "$yy_b" ]; then
        return 1
    fi
    if [ "$yy_a" -gt "$yy_b" ]; then
        return 0
    fi
    mm_a="$(echo "$1" | cut -d'.' -f2)"
    mm_b="$(echo "$2" | cut -d'.' -f2)"
    if [ "${mm_a}" -lt "${mm_b}" ]; then
        return 1
    fi

    return 0
)

join_by() {
    local d=$1
    shift
    printf '%s\n' "$@" | paste -sd "$d"
}

function your_cpu_core_number() {
    local cpu_s=$(awk -F':' '/physical id/ {print $NF+1}' /proc/cpuinfo | tail -n 1)
    local cpu_sockets=$(awk -F':' '/^siblings/ {print $NF+0;exit}' /proc/cpuinfo)
    echo $(($cpu_s * $cpu_sockets))
}

is_uint() { case $1 in '' | *[!0-9]*) return 1 ;; esac }
is_int() { case ${1#[-+]} in '' | *[!0-9]*) return 1 ;; esac }
is_unum() { case $1 in '' | . | *[!0-9.]* | *.*.*) return 1 ;; esac }
is_num() { case ${1#[-+]} in '' | . | *[!0-9.]* | *.*.*) return 1 ;; esac }
