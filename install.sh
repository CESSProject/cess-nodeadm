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
    --skip-dep            skip install the dependencies for cess-nodeadm
    --retain-config       retain old config when update cess-nodeadm, only valid on update option
    --docker-mirror       optional, Aliyun or AzureChinaCloud
EOF
exit 0
}

install_dependencies()
{
    if [ x"$skip_dep" == x"true" ]; then
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
        rm -f /usr/bin/yq
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
    local dst_bin=/usr/bin/cess
    local dst_config=$install_dir/config.yaml
    local dst_utils_sh=$install_dir/scripts/utils.sh
    local src_utils_sh=$local_base_dir/scripts/utils.sh
    local old_version=""
    local new_version=""
    if [ -f "$dst_utils_sh" ]; then
        old_version=$(cat $dst_utils_sh | grep nodeadm_version | awk -F = '{gsub(/"/,"");print $2}')
    fi
    if [ -f "$src_utils_sh" ]; then
        new_version=$(cat $src_utils_sh | grep nodeadm_version | awk -F = '{gsub(/"/,"");print $2}')
    fi
    
    echo "Begin install cess nodeadm $new_version"
    
    if [ -f "$dst_config" ] && [ x"$retain_config" != x"true" ]; then
        log_info "WARNING: It is detected that you may have previously installed cess nodeadm $old_version"
        log_info "         and that a new installation will overwrite the original configuration."
        log_info "         Request to make sure you have backed up the relevant important configuration data."
        printf "Press \033[0;33mY\033[0m to continue: "
        local y=""
        read y
        if [ x"$y" != x"Y" ]; then
            echo "install operate cancel"
            return 1
        fi
    fi

    local old_config=$local_base_dir/.old_config.yaml
    if [ x"$retain_config" == x"true" ]; then
        cp $dst_config $old_config
    fi

    if [ -f "$install_dir/scripts/uninstall.sh" ]; then
        echo "Uninstall old cess nodeadm $old_version"
        $install_dir/scripts/uninstall.sh
    fi

    mkdir -p $install_dir

    if [ -f $old_config ]; then
        mv $old_config $dst_config
    else
        cp $local_base_dir/config.yaml $dst_config
    fi
    chown root:root $install_dir/config.yaml
    chmod 0600 $install_dir/config.yaml

    cp -r $local_base_dir/scripts $install_dir/
    cp -r $local_base_dir/sgx-software-enable $install_dir/
     
    cp $local_script_dir/cess.sh /usr/bin/cess

    log_success "Install cess nodeadm success"
}

skip_dep="false"
retain_config="false"

while true ; do
    case "$1" in
        --docker-mirror)
            docker_mirror=$2
            shift 2
            ;;
        --skip-dep)
            skip_dep="true"
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

install_dependencies
install_cess_node
