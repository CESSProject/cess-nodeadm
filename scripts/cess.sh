#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh
source /opt/cess/nodeadm/scripts/version.sh
source /opt/cess/nodeadm/scripts/config.sh
source /opt/cess/nodeadm/scripts/tools.sh

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

function down() {
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi
    log_info "remove all service"
    docker compose -f $compose_yaml down -v
}

function pullimg() {
    docker pull cesslab/config-gen:$profile
    if [ -f "$compose_yaml" ]; then
        docker compose -f $compose_yaml pull
    fi
}

status()
{
    docker ps -a -f "label=com.docker.compose.project=cess-$mode" --format 'table {{.Names}}\t{{.Status}}'
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

    local bucket_image="cesslab/cess-bucket:$profile"    
    local cmd="docker run --rm --network=host $volumes $bucket_image ./cess-bucket"
    local -r cfg_arg="-c /opt/bucket/config.yaml"
    case "$1" in
        increase)
            $cmd $1 $2 $cfg_arg
            ;;
        exit)
            $cmd $1 $cfg_arg
            ;;
        withdraw)
            $cmd $1 $cfg_arg
            ;;
        stat)
            $cmd $1 $cfg_arg
            ;;
        reward)
            $cmd $1 $2 $cfg_arg
            ;;
        claim)
            $cmd $1 $2 $cfg_arg
            ;;
        update)
            if [ "$2" == "earnings" ]; then
                $cmd $1 $2 $3 $cfg_arg
            else
                bucket_ops_help
            fi
            ;;
        *)
            bucket_ops_help
    esac
}

bucket_ops_help()
{
cat << EOF
cess bucket usage (only on storage mode):
    increase [amount]                   Increase the stakes of storage miner
    exit                                Unregister the storage miner role
    withdraw                            Withdraw stakes
    stat                                Query storage miner information
    reward                              Query reward information
    claim                               Claim reward    
    update earnings [wallet account]    Update earnings account 
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

    if [ x"$1" = x"bucket" ]; then
        purge_bucket
        return $?
    fi
    help
    return 1
}

function purge_chain()
{
    stop chain
    rm -rf /opt/cess/$mode/chain/*
    if [ $? -eq 0 ]; then
        log_success "purge chain data success"
    fi
}

function purge_bucket()
{
    stop bucket
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
    down                                      stop and remove all service

    status                              check service status
    pullimg                             update all service images
    purge {chain|kaleido|bucket}        remove datas regarding program, WARNING: this operate can't revert, make sure you understand you do 
    
    config {...}                        configuration operations, use 'cess config help' for more details
    profile {devnet|testnet|mainnet}    switch CESS network profile, testnet for default
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
    down)
        down
        ;;
    status)
        status $2
        ;;
    pullimg)
        pullimg
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
    profile)
        set_profile $2
        ;;
    tools)
        shift
        tools $@
        ;;
    *)
        help
esac
exit 0
