#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh
source /opt/cess/nodeadm/scripts/version.sh
source /opt/cess/nodeadm/scripts/config.sh
source /opt/cess/nodeadm/scripts/tools.sh

mode=$(yq eval ".node.mode" $config_file)
if [ $? -ne 0 ]; then
    log_err "the config file: $config_file may be invalid, please reconfig again"
    exit 1
fi

########################################base################################################

start()
{
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi

    docker compose -f $compose_yaml up -d $1
    return $?
}

stop()
{
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi

    docker compose -f $compose_yaml stop $1
    return $?
}

restart() {
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi

    docker compose -f $compose_yaml restart $1
    return $?
}

reload() {
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi

    if [ x"$1" = x"" ]; then
        log_info "Reload all service"
        docker compose -f $compose_yaml down
        if [ $? -eq 0 ]; then
            docker compose -f $compose_yaml up -d
        fi
        return $?
    fi    

    docker compose -f $compose_yaml rm -fs $1
    if [ $? -eq 0 ]; then
        docker compose -f $compose_yaml up -d        
    fi
    return $?
}

status()
{
    docker ps -a --format 'table {{.Names}}\t{{.Status}}'
}

bucket_ops()
{
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    local volumes=$(yq eval ".services.bucket.volumes" $base_dir/build/docker-compose.yaml | cut -d\' -f 2 | sed -n '1h;1!H;${g;s/\n/ -v /g;p;}')
    if [ x"$volumes" != x"" ]; then
        volumes="-v "$volumes
    fi

    local bucket_image=(`docker images | grep '^\b'cesslab/cess-bucket'\b ' | grep 'latest'`)
    bucket_image=${bucket_image[2]}
    local cmd="docker run --rm --network=host $volumes $bucket_image ./cess-bucket"
    local -r cfg_arg="-c /opt/bucket/config.toml"
    case "$1" in
        register)
            $cmd register $cfg_arg
            ;;
        increase)
            $cmd increase $2 $cfg_arg
            ;;
        exit)
            $cmd exit $cfg_arg
            ;;
        withdraw)
            $cmd withdraw $2 $cfg_arg
            ;;
        state)
            $cmd state $cfg_arg
            ;;
        update_address)
            $cmd update_address $2 $cfg_arg
            ;;
        update_income)
            $cmd update_income $2 $cfg_arg
            ;;
        *)
            bucket_ops_help
    esac
}

bucket_ops_help()
{
cat << EOF
cess bucket usage (only on storage mode):
    register                   Register mining miner information to the chain
    increase [amount]          Increase the deposit of mining miner
    exit                       Exit the mining platform
    withdraw                   Redemption deposit
    state                      Query mining miner information
    update_address [ip:port]   Update the miner's access address
    update_income [account]    Update the miner's income account
EOF
}

function purge()
{
    log_info "WARNING: this operate can remove your data regarding program and can't revert."
    log_info "         Make sure you understand you do!"
    printf "Press \033[0;33mY\033[0m if you really want to do: "
    local y=""
    read y
    if [ x"$y" != x"Y" ]; then
        echo "purge operate cancel"
        return 1
    fi

    if [ x"$1" = x"" ]; then
        if [ x"$mode" == x"authority" ]; then
            purge_scheduler
            purge_chain
        elif [ x"$mode" == x"storage" ]; then
            purge_bucket
            purge_chain
        elif [ x"$mode" == x"watcher" ]; then
            purge_chain
        fi
        return $?
    fi

    if [ x"$1" = x"chain" ]; then
        purge_chain
        return $?
    fi

    if [ x"$1" = x"scheduler" ]; then
        purge_scheduler
        return $?
    fi

    if [ x"$1" = x"bucket" ]; then
        purge_bucket
        return $?
    fi
    help
    return 1
}

function purge_chain()
{
    stop_chain
    rm -rf /opt/cess/$mode/chain/*
    if [ $? -eq 0 ]; then
        log_success "purge chain data success"
    fi
}

function purge_bucket()
{
    stop_bucket
    rm -rf /opt/cess/$mode/bucket/*
    if [ $? -eq 0 ]; then
        log_success "purge bucket data success"
    fi
}

######################################main entrance############################################

help()
{
cat << EOF
Usage:
    help                                      show help information
    version                                   show version

    start {chain|kld-sgx|kld-agent|bucket}    start all or one cess service
    stop {chain|kld-sgx|kld-agent|bucket}     stop all or one cess service
    reload {chain|kld-sgx|kld-agent|bucket}   reload (stop remove then start) all or one service
    restart {chain|kld-sgx|kld-agent|bucket}  restart all or one cess service

    status                              check service status
    purge {chain|kaleido|bucket}        remove datas regarding program, WARNING: this operate can't revert, make sure you understand you do 
    
    config {...}                        configuration operations, use 'cess config help' for more details
    bucket {...}                        use 'cess bucket help' for more details
    tools {...}                         use 'cess tools help' for more details
EOF
}

load_profile

case "$1" in
    version)
        version
        ;;
    start)
        shift
        start $@
        ;;
    stop)
        stop $2
        ;;
    restart)
        shift
        reload $@
        ;;
    reload)
        shift
        reload $@
        ;;
    status)
        status $2
        ;;
    logs)
        shift
        logs $@
        ;;
    purge)
        shift
        purge $@
        ;;
    bucket)
        shift
        bucket_ops $@
        ;;
    config)
        shift
        config $@
        ;;
    tools)
        shift
        tools $@
        ;;
    *)
        help
esac
exit 0
