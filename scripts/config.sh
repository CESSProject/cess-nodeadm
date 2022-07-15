#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh

config_help()
{
cat << EOF
cess config usage:
    help                    show help information
    show                    show configurations
    set                     set and generate new configurations
    generate                generate new configurations
    chain-port {port}       set chain port and generate new configuration, default is 30888
    conn-chain {ws}         set conneted chain ws and generate new configuration, default is ws://127.0.0.1:19944
EOF
}

config_show()
{
    cat $config_file
}

set_chain_name()
{
    local -r default="cess-node"
    local to_set=""
    local current="`yq eval ".chain.name" $config_file`"
    if [ x"$current" != x"" ]; then
        read -p "Enter cess node name (current: $current, press enter to skip): " to_set
    else
        read -p "Enter cess node name (default: $default): " to_set
    fi
    to_set=`echo "$to_set"`
    if [ x"$to_set" != x"" ]; then
        local rn=$(rand 100000 999999)
        yq -i eval ".chain.name=\"$to_set-$rn\"" $config_file
    elif [ x"$current" == x"" ]; then
        local rn=$(rand 100000 999999)
        yq -i eval ".chain.name=\"$default-$rn\"" $config_file
    fi
}

set_node_mode()
{
    local -r default="authority"
    local to_set=""
    local current=$mode
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess node mode from 'authority/storage/watcher' (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess node mode from 'authority/storage/watcher' (default: $default): " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            if [ x"$to_set" == x"authority" ] || [ x"$to_set" == x"storage" ] || [ x"$to_set" == x"watcher" ]; then
                if [ x"$to_set" != x"$mode" ]; then
                    mode=$to_set
                    yq -i eval ".node.mode=\"$to_set\"" $config_file
                fi
                break
            else
                log_err "Input error, please input 'authority' 'storage' or 'watcher'"
                continue
            fi
        elif [ x"$current" == x"" ]; then
            mode=$default
            yq -i eval ".node.mode=\"$default\"" $config_file
            break
        fi
        break
    done
    local path_with_mode="/opt/cess/$mode/"
    if [ ! -d path_with_mode ]; then
        mkdir -p $path_with_mode        
    fi
}

set_external_ip()
{
    local ip=""
    local current="`yq eval ".node.externalIp" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter external ip for the machine (current: $current, press enter to skip): " ip
        else
            read -p "Enter external ip for the machine: " ip
        fi
        ip=`echo "$ip"`
        if [ x"$ip" != x"" ]; then
            yq -i eval ".node.externalIp=\"$ip\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_domain_name()
{
    local to_set=""
    local current="`yq eval ".node.domainName" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter a domain name for the machine (current: $current, press enter to skip): " to_set
        else
            read -p "Enter a domain name for the machine: " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            yq -i eval ".node.domainName=\"$to_set\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_chain_ws_url()
{
    local -r default="ws://127.0.0.1:9948"
    local to_set=""
    local current="`yq eval ".node.chainWsUrl" $config_file`"
    if [ x"$current" != x"" ]; then
        read -p "Enter cess chain ws url (current: $current, press enter to skip): " to_set
    else
        read -p "Enter cess chain ws url (default: $default): " to_set
    fi
    to_set=`echo "$to_set"`
    if [ x"$to_set" != x"" ]; then
        yq -i eval ".node.chainWsUrl=\"$to_set\"" $config_file
    elif [ x"$current" == x"" ]; then
        yq -i eval ".node.chainWsUrl=\"$default\"" $config_file
    fi
}

set_scheduler_stash_account()
{
    local stash_acc=""
    local current="`yq eval ".scheduler.stashAccount" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess scheduler stash account (current: $current, press enter to skip): " stash_acc
        else
            read -p "Enter cess scheduler stash account: " stash_acc
        fi
        stash_acc=`echo "$stash_acc"`
        if [ x"$stash_acc" != x"" ]; then
            yq -i eval ".scheduler.stashAccount=\"$stash_acc\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_scheduler_ctrl_phrase()
{
    local to_set=""
    local current="`yq eval ".scheduler.controllerPhrase" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess scheduler controller phrase (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess scheduler controller phrase: " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            yq -i eval ".scheduler.controllerPhrase=\"$to_set\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_authority_phrase()
{
    local to_set=""
    local current="`yq eval ".chain.authorityPhrase" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess chain authority phrase (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess chain authority phrase: " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            yq -i eval ".chain.authorityPhrase=\"$to_set\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_bucket_income_account()
{
    local to_set=""
    local current="`yq eval ".bucket.incomeAccount" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess bucket income account (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess bucket income account: " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            yq -i eval ".bucket.incomeAccount=\"$to_set\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_bucket_sign_phrase()
{
    local to_set=""
    local current="`yq eval ".bucket.signPhrase" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess bucket signature phrase (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess bucket signature phrase: " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            yq -i eval ".bucket.signPhrase=\"$to_set\"" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

set_bucket_disk_path()
{
    local -r default="/opt/cess/storage/disk"
    local to_set=""
    local current="`yq eval ".bucket.diskPath" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess bucket disk path (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess bucket disk path (default: $default): " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            if [ ! -e $to_set ] || [ -f $to_set ]; then
                log_err "the path: $to_set not exists or not a directory"
                continue
            fi
            yq -i eval ".bucket.diskPath=\"$to_set\"" $config_file
            break
        elif [ x"$current" == x"" ]; then
            if [ ! -e $default ] || [ -f $default ]; then
                log_err "the path: $default not exists or not a directory"
                continue
            fi
            yq -i eval ".bucket.diskPath=\"$default\"" $config_file
            break
        fi
        break
    done
}

set_bucket_disk_spase()
{
    local to_set=""
    local current="`yq eval ".bucket.space" $config_file`"
    while true
    do
        if [ x"$current" != x"" ]; then
            read -p "Enter cess bucket space, by GB unit (current: $current, press enter to skip): " to_set
        else
            read -p "Enter cess bucket space, by GB unit: " to_set
        fi
        to_set=`echo "$to_set"`
        if [ x"$to_set" != x"" ]; then
            yq -i eval ".bucket.space=$to_set" $config_file
            break
        elif [ x"$current" != x"" ]; then
            break
        fi
    done
}

config_set_all()
{
    ensure_root
    
    set_node_mode
    
    if [ x"$mode" == x"authority" ]; then
        set_chain_name
        set_external_ip
        set_chain_ws_url
        set_scheduler_stash_account
        set_scheduler_ctrl_phrase
    elif [ x"$mode" == x"storage" ]; then
        local use_domain=0
        echo "Which way to use to give the outsider access to the machine?"
        read -p "    [0] use external IP; [1] use domain name (default 0): " use_domain
        if [ x"$use_domain" == x"0" ] || [ x"$use_domain" == x"" ]; then
            set_external_ip
            yq -i eval ".node.domainName=\"\"" $config_file
        else
            set_domain_name
        fi
        set_chain_ws_url
        set_bucket_income_account
        set_bucket_sign_phrase
        set_bucket_disk_path
        set_bucket_disk_spase
    elif [ x"$mode" == x"watcher" ]; then
        set_chain_name
        set_external_ip
    else
        log_err "Invalid mode value: $mode"
        exit 1
    fi
    log_success "Set configurations successfully"
    
    # Generate configurations
    config_generate
}

config_conn_chain()
{
    if [ x"$1" = x"" ]; then
        log_err "Please give connceted chain ws."
        config_help
        return 1
    fi
    yq -i eval ".node.chainWsUrl=\"$1\"" $config_file
    log_success "Set connected chain ws '$1' successfully"
    config_generate
}

config_chain_port()
{
    if [ x"$1" = x"" ]; then
        log_err "Please give right chain port."
        config_help
        return 1
    fi
    yq -i eval ".chain.port=$1" $config_file
    log_success "Set chain port '$1' successfully"
    config_generate
}

config_generate()
{
    log_info "Start generate configurations and docker compose file"
    local cg_image="cesslab/config-gen:latest"

    if [ ! -f "$config_file" ]; then
        log_err "config.yaml doesn't exists!"
        exit 1
    fi

    rm -rf $build_dir
    mkdir -p $build_dir/.tmp

    cp -f $config_file $build_dir/
    local cidfile=`mktemp`
    rm $cidfile

    docker run --cidfile $cidfile -v $base_dir/etc:/opt/app/etc -v $build_dir/.tmp:/opt/app/.tmp -v $build_dir/config.yaml:/opt/app/config.yaml $cg_image
    local res="$?"
    local cid=`cat $cidfile`
    docker rm $cid

    if [ "$res" -ne "0" ]; then
        log_err "Failed to generate application configs, please check your config.yaml"
        exit 1
    fi

    cp -r $build_dir/.tmp/* $build_dir/
    rm -rf $build_dir/.tmp
    local base_mode_path=/opt/cess/$mode
    if [ x"$mode" == x"authority" ]; then
        if [ ! -d $base_mode_path/chain/ ]; then
            mkdir -p $base_mode_path/chain/
        fi
        cp $build_dir/chain/* $base_mode_path/chain/
        
        if [ ! -d $base_mode_path/scheduler/ ]; then
            mkdir -p $base_mode_path/scheduler/
        fi
        cp $build_dir/scheduler/* $base_mode_path/scheduler/
    elif [ x"$mode" == x"storage" ]; then
        if [ ! -d $base_mode_path/bucket/ ]; then
            mkdir -p $base_mode_path/bucket/
        fi
        cp $build_dir/bucket/* $base_mode_path/bucket/
    elif [ x"$mode" == x"watcher" ]; then
        if [ ! -d $base_mode_path/chain/ ]; then
            mkdir -p $base_mode_path/chain/
        fi
        cp $build_dir/chain/* $base_mode_path/chain/
    else
        log_err "Invalid mode value: $mode"
        exit 1
    fi
    chown -R root:root $build_dir
    #chmod -R 0600 $build_dir
    #chmod 0600 $config_file

    log_success "Configurations generated at: $build_dir"
}

config()
{
    case "$1" in
        show)
            config_show
            ;;
        set)
            config_set_all
            ;;
        conn-chain)
            shift
            config_conn_chain $@
            ;;
        chain-port)
            shift
            config_chain_port $@
            ;;
        generate)
            config_generate
            ;;
        *)
            config_help
    esac
}
