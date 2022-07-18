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
    help                       show help information
    --update                   update cess node
    --region {cn|en}           use region to accelerate docker pull
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
        apt install -y git yq curl wget net-tools build-essential kmod linux-headers-`uname -r` vim
        yq -V >/dev/null
        if [ $? -ne 0 ]; then
            wget https://github.com/mikefarah/yq/releases/download/v4.25.3/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
        fi

    elif [ x"$DISTRO" == x"CentOS" ]; then
        log_info "------------Yum update--------------"
        yum update
        if [ $? -ne 0 ]; then
            log_err "Yum update failed"
            exit 1
        fi
        log_info "------------Install depenencies--------------"
        yum install -y git yq curl wget net-tools vim
        yq -V >/dev/null
        if [ $? -ne 0 ]; then
            wget https://github.com/mikefarah/yq/releases/download/v4.25.3/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
        fi
    fi    

    if [ $? -ne 0 ]; then
        log_err "Install libs failed"
        exit 1
    fi

    docker -v
    if [ $? -ne 0 ]; then
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
        if [ $? -ne 0 ]; then
            log_err "Install docker failed"
            exit 1
        fi
    fi

    docker-compose -v
    if [ $? -ne 0 ]; then
        apt install -y docker-compose
        if [ $? -ne 0 ]; then
            log_err "Install docker compose failed"
            exit 1
        fi
    fi

    sysctl -w net.core.rmem_max=2500000
}

download_docker_images()
{
    if [ x"$update" == x"true" ]; then
        return 0
    fi

    log_info "-------Download cess docker images----------"
    
    local docker_org="cesslab"
    if [ x"$region" == x"cn" ]; then
       docker_org=$aliyun_address/$docker_org
    fi

    local res=0
    docker pull $docker_org/config-gen:latest
    res=$(($?|$res))
    docker tag $docker_org/config-gen:latest cesslab/config-gen
    
    local img_tag="latest"
    docker pull $docker_org/cess-chain:$img_tag
    res=$(($?|$res))
    docker tag $docker_org/cess-chain:$img_tag cesslab/cess-chain

    docker pull $docker_org/cess-scheduler:$img_tag
    res=$(($?|$res))
    docker tag $docker_org/cess-scheduler:$img_tag cesslab/cess-scheduler

    docker pull $docker_org/cess-bucket:$img_tag
    res=$(($?|$res))
    docker tag $docker_org/cess-bucket:$img_tag cesslab/cess-bucket
        
    if [ $res -ne 0 ]; then
        log_err "Install docker failed"
        exit 1
    fi
}

install_cess_node()
{
    log_info "--------------Install cess nodeadm-------------"
    local bin_file=/usr/bin/cess
     
    if [ -d "$install_dir" ] && [ -f "$bin_file" ] && [ x"$update" == x"true" ]; then
        echo "Update cess nodeadm"
        rm $bin_file
        rm -rf $install_dir/scripts
        rm -f $install_dir/config.yaml
        cp -r $local_base_dir/scripts $install_dir/
        cp $local_base_dir/config.yaml $install_dir/
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

        yq -i eval ".node.region=\"$region\"" $config_file
    fi

    echo "Install cess command line tool"
    cp $local_script_dir/cess.sh /usr/bin/cess

    log_success "------------Install success-------------"
}

region="en"
update="false"

while true ; do
    case "$1" in
        --region)
            if [ x"$2" == x"" ] || [[ x"$2" != x"cn" && x"$2" != x"en" ]]; then
                help
            fi
            region=$2
            shift 2
            ;;
        --update)
            update="true"
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
download_docker_images
install_cess_node
