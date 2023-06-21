#!/bin/bash

local_base_dir=$(cd `dirname $0`;pwd)
local_script_dir=$local_base_dir/scripts
install_dir=/opt/cess/nodeadm
source $local_script_dir/utils.sh

ensure_root

get_distro_name
if [ $? -ne 0 ]; then
    exit 1
fi
if [ x"$DISTRO" != x"Ubuntu" ] && [ x"$DISTRO" != x"CentOS" ]; then
    log_err "current only support Ubuntu or CentOS"
    exit 1
fi

help()
{
cat << EOF
Usage:
    help                  show help information
    --update              update cess-nodeadm script and config
    --retain-config       retain old config when update cess-nodeadm, only valid on update option
    --region {cn|en}      use region to accelerate docker pull
    --docker_mirror       optional, Aliyun or AzureChinaCloud
EOF
exit 0
}

install_depenencies()
{
    if [ x"$update" == x"true" ]; then
        return 0
    fi

    if [ x"$DISTRO" == x"Ubuntu" ]; then
        log_info "------------Apt update--------------"
        apt-get update
        if [ $? -ne 0 ]; then
            log_err "Apt update failed"
            exit 1
        fi

        log_info "------------Install depenencies--------------"
        apt-get install -y git jq curl wget net-tools

    elif [ x"$DISTRO" == x"CentOS" ]; then
        log_info "------------Yum update--------------"
        yum update
        if [ $? -ne 0 ]; then
            log_err "Yum update failed"
            exit 1
        fi
        log_info "------------Install depenencies--------------"
        yum install -y git jq curl wget net-tools        
    fi

    if [ $? -ne 0 ]; then
        log_err "Install libs failed"
        exit 1
    fi

    need_install_yq=1
    if command_exists yq; then
        ya_ver=$(yq -V | awk '{print $NF}' | cut -d . -f 1,2)
        if is_ver_a_ge_b $ya_ver 4.25; then
            need_install_yq=0
        fi
    fi
    if [ $need_install_yq -eq 1 ]; then
        wget https://github.com/mikefarah/yq/releases/download/v4.25.3/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
    fi

    if [ $? -ne 0 ]; then
        log_err "Install yq failed"
        exit 1
    fi

    need_install_docker=1
    if command_exists docker && [ -e /var/run/docker.sock ]; then
        current_docker_ver=$(docker version -f '{{.Server.Version}}')
        log_info "current docker version: $current_docker_ver"
        current_docker_ver=$(echo $current_docker_ver | cut -d . -f 1,2)
        if is_ver_a_ge_b $current_docker_ver 20.10; then
            need_install_docker=0
            log_info "don't need install or upgrade docker"
        fi
    fi

    if [ $need_install_docker -eq 1 ]; then
        # install or update docker
        mirror_opt=''
        if [ ! -z $docker_mirror]; then
            mirror_opt="--mirror $docker_mirror"
        fi
        curl -fsSL https://get.docker.com | bash -s docker $mirror_opt
        if [ $? -ne 0 ]; then
            log_err "Install docker failed"
            exit 1
        fi
    fi

    # check docker-compose-plugin
    if [ x"$DISTRO" == x"Ubuntu" ]; then
        local n=$(dpkg -l | grep docker-compose-plugin | wc -l)
        if [ $n -eq 0 ]; then
            apt-get install -y docker-compose-plugin
            if [ $? -ne 0 ]; then
                log_err "Install docker-compose-plugin failed"
                exit 1
            fi
        fi
    elif [ x"$DISTRO" == x"CentOS" ]; then        
        local n=$(rpm -qa | grep docker-compose-plugin | wc -l)
        if [ $n -eq 0 ]; then
            yum install -y docker-compose-plugin
            if [ $? -ne 0 ]; then
                log_err "Install docker-compose-plugin failed"                
                exit 1
            fi
        fi
    fi
    
    sysctl -w net.core.rmem_max=2500000
}

install_cess_node()
{
    log_info "--------------Install cess nodeadm-------------"
    local bin_file=/usr/bin/cess
     
    if [ -d "$install_dir" ] && [ -f "$bin_file" ] && [ x"$update" == x"true" ]; then
        echo "Update cess nodeadm"
        rm $bin_file
        rm -rf $install_dir/scripts
        cp -r $local_base_dir/scripts $install_dir/
        if [ x"$retain_config" != x"true" ]; then
            rm -f $install_dir/config.yaml
            cp $local_base_dir/config.yaml $install_dir/
        fi
    else
        if [ -f "$install_dir/scripts/uninstall.sh" ]; then
            echo "Uninstall old cess nodeadm"
            $install_dir/scripts/uninstall.sh
        fi

        echo "Install new cess nodeadm"
        mkdir -p $install_dir
        cp $local_base_dir/config.yaml $install_dir/
        chown root:root $install_dir/config.yaml
        chmod 0600 $install_dir/config.yaml
        cp -r $local_base_dir/scripts $install_dir/
        cp -r $local_base_dir/sgx-software-enable $install_dir/

        yq -i eval ".node.region=\"$region\"" $config_file
    fi

    echo "Install cess command line tool"
    cp $local_script_dir/cess.sh /usr/bin/cess

    log_success "------------Install success-------------"
}

region="en"
update="false"
retain_config="false"

while true ; do
    case "$1" in
        --region)
            if [ x"$2" == x"" ] || [[ x"$2" != x"cn" && x"$2" != x"en" ]]; then
                help
            fi
            region=$2
            shift 2
            ;;
        --docker_mirror)
            docker_mirror=$2
            shift 2
            ;;
        --update)
            update="true"
            shift 1
            ;;
        --retain-config)
            retain_config="true"
            shift 1
            ;;
        "")
            shift ;
            break ;;
        *)
            help
            break;
            ;;
    esac
done

install_depenencies
install_cess_node
