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

    if [ x"$1" = x"" ]; then
        log_info "Start cess"
        
        if [ x"$mode" == x"authority" ]; then
            start_chain
            if [ $? -ne 0 ]; then
                docker-compose -f $compose_yaml down
                exit 1
            fi

            start_scheduler
            if [ $? -ne 0 ]; then
                docker-compose -f $compose_yaml down
                exit 1
            fi

            start_kaleido
            if [ $? -ne 0 ]; then
                docker-compose -f $compose_yaml down
                exit 1
            fi
        elif [ x"$mode" == x"storage" ]; then
            start_bucket
            if [ $? -ne 0 ]; then
                docker-compose -f $compose_yaml down
                exit 1
            fi
        elif [ x"$mode" == x"watcher" ]; then
            start_chain
            if [ $? -ne 0 ]; then
                docker-compose -f $compose_yaml down
                exit 1
            fi
        else
            log_err "the config file may be invalid, please reconfig again"
            exit 1
        fi        

        log_success "Start cess success"
        return 0
    fi

    if [ x"$mode" == x"authority" ]; then
        if [ x"$1" = x"chain" ]; then
            log_info "Start chain service"
            start_chain
            if [ $? -ne 0 ]; then
                exit 1
            fi
            log_success "Start chain service success"
            return 0
        fi

        if [ x"$1" = x"scheduler" ]; then
            log_info "Start scheduler service"
            start_scheduler
            if [ $? -ne 0 ]; then
                exit 1
            fi
            log_success "Start scheduler service success"
            return 0
        fi

        if [ x"$1" = x"kaleido" ]; then
            log_info "Start kaleido service"
            start_kaleido
            if [ $? -ne 0 ]; then
                exit 1
            fi
            log_success "Start kaleido service success"
            return 0
        fi

    elif [ x"$mode" == x"storage" ]; then
        if [ x"$1" = x"bucket" ]; then
            log_info "Start bucket service"
            start_bucket
            if [ $? -ne 0 ]; then
                exit 1
            fi
            log_success "Start bucket service success"
            return 0
        fi
    elif [ x"$mode" == x"watcher" ]; then
        if [ x"$1" = x"chain" ]; then
            log_info "Start chain service"
            start_chain
            if [ $? -ne 0 ]; then
                exit 1
            fi
            log_success "Start chain service success"
            return 0
        fi
    fi

    log_err "unsupport operation on $mode mode"
    return 1
}

stop()
{
    if [ x"$1" = x"" ]; then
        log_info "Stop cess"
        stop_chain
        stop_scheduler
        stop_kaleido
        stop_bucket
        log_success "Stop cess success"
        return 0
    fi

    if [ x"$1" = x"chain" ]; then
        log_info "Stop chain service"
        stop_chain
        log_success "Stop chain service success"
        return 0
    fi

    if [ x"$1" = x"bucket" ]; then
        log_info "Stop bucket service"
        stop_bucket
        log_success "Stop bucket service success"
        return 0
    fi

    if [ x"$1" = x"scheduler" ]; then
        log_info "Stop scheduler service"
        stop_scheduler
        log_success "Stop scheduler service success"
        return 0
    fi

    if [ x"$1" == x"kaleido" ]; then
        log_info "Stop kaleido service"
        stop_kaleido
        log_success "Stop kaleido service success"
        return 0
    fi

    help
    return 1
}

start_chain()
{
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    check_docker_status chain
    if [ $? -eq 0 ]; then
        return 0
    fi

    local chain_port=`yq eval ".chain.port" $config_file`
    if [ x"$chain_port" = x"" ] || [ x"$chain_port" = x"null" ]; then
        chain_port=30336
    fi

    if [ $chain_port -lt 0 ] || [ $chain_port -gt 65535 ]; then
        log_err "The range of chain port is 0 ~ 65535"
        return 1
    fi

    local res=0
    check_port $chain_port
    res=$(($?|$res))
    check_port 9933  #check the RPC port
    res=$(($?|$res))
    check_port 9944  #check the WS port
    res=$(($?|$res))
    if [ $res -ne 0 ]; then
        return 1
    fi

    docker-compose -f $compose_yaml up -d chain
    if [ $? -ne 0 ]; then
        log_err "Start cess chain failed"
        return 1
    fi
    return 0
}

stop_chain()
{
    check_docker_status chain
    if [ $? -ne 1 ]; then
        log_info "Stopping cess chain service"
        docker stop chain &>/dev/null
        docker rm chain &>/dev/null
    fi
    return 0
}

start_scheduler()
{
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    check_docker_status scheduler
    if [ $? -eq 0 ]; then
        return 0
    fi

    docker-compose -f $compose_yaml up -d scheduler
    if [ $? -ne 0 ]; then
        log_err "Start cess scheduler failed"
        return 1
    fi
    return 0
}

stop_scheduler()
{
    check_docker_status scheduler
    if [ $? -ne 1 ]; then
        log_info "Stopping cess scheduler service"
        docker stop scheduler &>/dev/null
        docker rm scheduler &>/dev/null
    fi
    return 0
}

start_kaleido()
{
    # if [ ! -f "$compose_yaml" ]; then
    #     log_err "No configuration file, please set config"
    #     return 1
    # fi

    # check_docker_status kaleido
    # if [ $? -eq 0 ]; then
    #     return 0
    # fi

    # docker-compose -f $compose_yaml up -d kaleido
    # if [ $? -ne 0 ]; then
    #     log_err "Start cess kaleido failed"
    #     return 1
    # fi
    return 0
}

stop_kaleido()
{
    # check_docker_status kaleido
    # if [ $? -ne 1 ]; then
    #     log_info "Stopping cess kaleido service"
    #     docker stop kaleido &>/dev/null
    #     docker rm kaleido &>/dev/null
    # fi
    return 0
}

start_bucket()
{
    if [ ! -f "$compose_yaml" ]; then
        log_err "No configuration file, please set config"
        return 1
    fi

    check_docker_status bucket
    if [ $? -eq 0 ]; then
        return 0
    fi

    docker-compose -f $compose_yaml up -d bucket
    if [ $? -ne 0 ]; then
        log_err "Start cess bucket failed"
        return 1
    fi
    return 0
}

stop_bucket()
{
    check_docker_status bucket
    if [ $? -ne 1 ]; then
        log_info "Stopping cess bucket service"
        docker stop bucket &>/dev/null
        docker rm bucket &>/dev/null
    fi
    return 0
}

reload() {
    if [ x"$1" = x"" ]; then
        log_info "Reload all service"
        stop
        start
        log_success "Reload all service success"
        return 0
    fi

    if [ x"$1" = x"chain" ]; then
        log_info "Reload chain service"

        stop_chain
        start_chain

        log_success "Reload chain service success"
        return 0
    fi

    if [ x"$1" = x"scheduler" ]; then
        log_info "Reload scheduler service"
        
        stop_scheduler
        start_scheduler

        log_success "Reload scheduler service success"
        return 0
    fi

    if [ x"$1" = x"kaleido" ]; then
        log_info "Reload kaleido service"
        
        stop_kaleido
        start_kaleido

        log_success "Reload kaleido service success"
        return 0
    fi

    if [ x"$1" = x"bucket" ]; then
        log_info "Reload bucket service"
        
        stop_bucket
        start_bucket

        log_success "Reload bucket service success"
        return 0
    fi

    help
    return 1
}

########################################logs################################################

logs_help()
{
cat << EOF
Usage: cess logs [OPTIONS] {chain|scheduler|bucket}

Fetch the logs of a service

Options:
      --details        Show extra details provided to logs
  -f, --follow         Follow log output
      --since string   Show logs since timestamp (e.g. 2013-01-02T13:23:37) or relative (e.g. 42m for 42 minutes)
      --tail string    Number of lines to show from the end of the logs (default "all")
  -t, --timestamps     Show timestamps
      --until string   Show logs before a timestamp (e.g. 2013-01-02T13:23:37) or relative (e.g. 42m for 42 minutes)
EOF
}

logs()
{
    local name="${!#}"
    local array=( "$@" )
    local logs_help_flag=0
    unset "array[${#array[@]}-1]"

    if [ x"$name" == x"chain" ]; then
        check_docker_status chain
        if [ $? -eq 1 ]; then
            log_info "Service cess chain is not started now"
            return 0
        fi
        docker logs ${array[@]} -f chain
        logs_help_flag=$?
    elif [ x"$name" == x"scheduler" ]; then
        check_docker_status scheduler
        if [ $? -eq 1 ]; then
            log_info "Service cess scheduler is not started now"
            return 0
        fi
        docker logs ${array[@]} -f scheduler
        logs_help_flag=$?
    elif [ x"$name" == x"bucket" ]; then        
        check_docker_status bucket
        if [ $? -eq 1 ]; then
            log_info "Service cess bucket is not started now"
            return 0
        fi
        docker logs ${array[@]} -f bucket
        logs_help_flag=$?
    elif [ x"$name" == x"kaleido" ]; then        
        check_docker_status kaleido
        if [ $? -eq 1 ]; then
            log_info "Service cess kaleido is not started now"
            return 0
        fi
        docker logs ${array[@]} -f kaleido
        logs_help_flag=$?    
    else
        logs_help
        return 1
    fi

    if [ $logs_help_flag -ne 0 ]; then
        logs_help
        return 1
    fi
}

#######################################status################################################

status()
{
    if [ x"$1" == x"chain" ]; then
        chain_status
    elif [ x"$1" == x"scheduler" ]; then
        scheduler_status
    elif [ x"$1" == x"bucket" ]; then
        bucket_status
    elif [ x"$1" == x"kaleido" ]; then
        kaleido_status
    elif [ x"$1" == x"" ]; then
        all_status
    else
        help
    fi
}

all_status()
{
cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
EOF
    local chain_status="stop"
    local scheduler_status="stop"
    local bucket_status="stop"
    local kaleido_status="stop"
    if [ x"$mode" == x"authority" ] || [ x"$mode" == x"watcher" ]; then
        check_docker_status chain
        local res=$?
        if [ $res -eq 0 ]; then
            chain_status="running"
        elif [ $res -eq 2 ]; then
            chain_status="exited"
        fi
        echo "    chain                      ${chain_status}"
    fi

    if [ x"$mode" == x"authority" ]; then
        check_docker_status scheduler
        res=$?
        if [ $res -eq 0 ]; then
            scheduler_status="running"
        elif [ $res -eq 2 ]; then
            scheduler_status="exited"
        fi
        echo "    scheduler                  ${scheduler_status}"

        # check_docker_status kaleido
        # res=$?
        # if [ $res -eq 0 ]; then
        #     kaleido_status="running"
        # elif [ $res -eq 2 ]; then
        #     kaleido_status="exited"
        # fi
        # echo "    kaleido                    ${kaleido_status}"
    fi

    if [ x"$mode" == x"storage" ]; then
        check_docker_status bucket
        res=$?
        if [ $res -eq 0 ]; then
            bucket_status="running"
        elif [ $res -eq 2 ]; then
            bucket_status="exited"
        fi
        echo "    bucket                     ${bucket_status}"
    fi
    
cat << EOF
-----------------------------------------
EOF
}

chain_status()
{
    local chain_status="stop"

    check_docker_status chain
    local res=$?
    if [ $res -eq 0 ]; then
        chain_status="running"
    elif [ $res -eq 2 ]; then
        chain_status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    chain                      ${chain_status}
-----------------------------------------
EOF
}

scheduler_status()
{
    local status="stop"

    check_docker_status scheduler
    res=$?
    if [ $res -eq 0 ]; then
        status="running"
    elif [ $res -eq 2 ]; then
        status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    scheduler                  ${status}
-----------------------------------------
EOF
}

kaleido_status()
{
    local status="stop"

    check_docker_status kaleido
    res=$?
    if [ $res -eq 0 ]; then
        status="running"
    elif [ $res -eq 2 ]; then
        status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    kaleido                    ${status}
-----------------------------------------
EOF
}

bucket_status()
{
    local status="stop"

    check_docker_status bucket
    res=$?
    if [ $res -eq 0 ]; then
        status="running"
    elif [ $res -eq 2 ]; then
        status="exited"
    fi

cat << EOF
-----------------------------------------
    Service                    Status
-----------------------------------------
    bucket                     ${status}
-----------------------------------------
EOF
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
    withdraw [amount]          Redemption deposit
    state                      Query mining miner information
    update_address [ip:port]   Update the miner's access address
    update_income [account]    Update the miner's income account
EOF
}

######################################main entrance############################################

help()
{
cat << EOF
Usage:
    help                                show help information
    version                             show version

    start {chain|scheduler|bucket}      start all cess service
    stop {chain|scheduler|bucket}       stop all cess service or stop one service

    status {chain|scheduler|bucket}     check status or reload one service status
    reload {chain|scheduler|bucket}     reload all service or reload one service
    logs {chain|scheduler|bucket}       track service logs, ctrl-c to exit. use 'cess logs help' for more details
    
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
