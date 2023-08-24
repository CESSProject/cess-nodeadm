#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh

tools_help()
{
cat << EOF
cess tools usage:
    rotate-keys                                            generate session key of chain node
    space-info                                             show information about bucket disk
    help                                                   show help information
EOF
}

space_info()
{
    if [ x"$mode" != x"storage" ]; then
        log_info "Only on storage mode"
        exit 1
    fi
    local disk_path=`yq eval ".bucket.diskPath" $config_file`
    local info=(`df -h $disk_path | sed -n '2p'`)
cat << EOF
>>>>>> Mounted disk <<<<<<
Path: $disk_path
File system: ${info[0]}
Total space: ${info[1]}
Used space: ${info[2]}
Avail space: ${info[3]}
EOF
}

rotate_keys()
{
    check_docker_status chain
    if [ $? -ne 0 ]; then
        log_info "Service chain is not started or exited now"
        return 0
    fi

    local res=`docker exec chain curl -H 'Content-Type: application/json' -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:9933 2>/dev/null`
    session_key=`echo $res | jq .result`
    if [ x"$session_key" = x"" ]; then
        log_err "Generate session key failed"
        return 1
    fi
    echo $session_key
}

set_extra_cmd_args()
{
    local name=$1
    shift
    local cmd_args=$@
    if [ x"$name" == x"chain" ] || [ x"$name" == x"bucket" ]; then
        if [ x"$cmd_args" == x"" ]; then
            log_err "cmd_args must not be empty"
            return 1
        fi
        yq -i eval ".$name.extraCmdArgs=\"$cmd_args\"" $config_file
        if [ $? == 0 ]; then
            log_info "the extraCmdArgs of $name is set to \"$cmd_args\", use 'cess config generate' to update"
            return 0
        fi
    else
        log_err "invalid container name: $name, options: {chain|bucket}"
    fi
    return 1
}

set_no_watch_containers() {
    local names=($@)
    local quoted_names=()
    for ix in  ${!names[*]}; do
        quoted_names+=(\"${names[$ix]}\")
    done    
    local ss=$(join_by , ${quoted_names[@]})
    yq -i eval ".node.noWatchContainers=[$ss]" $config_file
}

tools()
{
    case "$1" in
        rotate-keys)
            rotate_keys
            ;;
        space-info)
            space_info
            ;;
        cmd_args)
            shift
            set_extra_cmd_args $@
            ;;
        no_watchs)
            shift
            set_no_watch_containers $@
            ;;
        *)
            tools_help
    esac
}
