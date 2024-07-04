#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh
source /opt/cess/nodeadm/scripts/version.sh
source /opt/cess/nodeadm/scripts/config.sh
source /opt/cess/nodeadm/scripts/tools.sh

########################################base################################################

start() {
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        exit 1
    fi
    
    docker compose -f $compose_yaml up -d $1
    return $?
}

stop() {
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

status() {
    docker ps -a -f "label=com.docker.compose.project=cess-$mode" --format 'table {{.Names}}\t{{.Status}}'
}

miner_ops() {
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    local volumes=$(yq eval ".services.miner.volumes" $base_dir/build/docker-compose.yaml | cut -d\' -f 2 | sed -n '1h;1!H;${g;s/\n/ -v /g;p;}')
    if [ x"$volumes" != x"" ]; then
        volumes="-v "$volumes
    fi

    local miner_image="cesslab/cess-miner:$profile"
    local cmd="docker run --rm --network=host $volumes $miner_image"
    local -r cfg_arg="-c /opt/miner/config.yaml"
    case "$1" in
    increase)
        $cmd $1 $2 $3 $cfg_arg
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
            miner_ops_help
        fi
        ;;
    *)
        miner_ops_help
        ;;
    esac
}

miner_ops_help() {
    cat <<EOF
cess miner usage (only on storage mode):
    increase [amount]                   Increase the stakes of storage miner
    exit                                Unregister the storage miner role
    withdraw                            Withdraw stakes
    stat                                Query storage miner information
    reward                              Query reward information
    claim                               Claim reward    
    update earnings [wallet account]    Update earnings account 
EOF
}

function purge() {
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
            purge_ceseal
        elif [ x"$mode" == x"storage" ]; then
            purge_miner
            purge_chain
        elif [[ "$mode" == "watcher" || "$mode" == "rpcnode" ]]; then
            purge_chain
        fi
        return $?
    fi

    if [ x"$1" = x"chain" ]; then
        purge_chain
        return $?
    fi

    if [ x"$1" = x"miner" ]; then
        purge_miner
        return $?
    fi

    if [ x"$1" = x"ceseal" ]; then
        purge_ceseal
        return $?
    fi

    log_err "purge with bad argument, usage: purge {chain|ceseal|miner}"
    return 1
}

function purge_chain() {
    stop chain
    rm -rf /opt/cess/$mode/chain/*
    if [ $? -eq 0 ]; then
        log_success "purge chain data success"
    fi
}

function purge_miner() {
    stop miner
    rm -rf /opt/cess/$mode/miner/*
    if [ $? -eq 0 ]; then
        log_success "purge miner data success"
    fi
}

function purge_ceseal() {
    stop cifrost
    stop ceseal
    rm -rf /opt/cess/$mode/ceseal/*
    if [ $? -eq 0 ]; then
        log_success "purge ceseal data success"
    fi
}

######################################main entrance############################################

help() {
    cat <<EOF
Usage:
    help                                        show help information
    version                                     show version

    start {chain|ceseal|cifrost|miner}          start all or one cess service
    stop {chain|ceseal|cifrost|miner}           stop all or one cess service
    reload {chain|ceseal|cifrost|miner}         reload (stop remove then start) all or one service
    restart {chain|ceseal|cifrost|miner}        restart all or one cess service
    down                                        stop and remove all service

    status                                      check service status
    pullimg                                     update all service images
    purge {chain|ceseal|miner}                  remove datas regarding program, WARNING: this operate can't revert, make sure you understand you do
    
    config {...}                                configuration operations, use 'cess config help' for more details
    profile {devnet|testnet|mainnet|ownnet}     switch CESS network profile, testnet for default
    miner {...}                                 use 'cess miner help' for more details
    tools {...}                                 use 'cess tools help' for more details
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
miner)
    shift
    miner_ops $@
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
    ;;
esac
exit 0
