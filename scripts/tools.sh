#!/bin/bash

source /opt/cess/nodeadm/scripts/utils.sh

tools_help()
{
cat << EOF
cess tools usage:
    rotate-keys                                            generate session key of chain node
    space-info                                             show information about bucket disk
    upgrade-image {chain|scheduler|bucket|config-gen}      upgrade one docker image
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

    local res=`curl -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:9933 2>/dev/null`
    session_key=`echo $res | jq .result`
    if [ x"$session_key" = x"" ]; then
        log_err "Generate session key failed"
        return 1
    fi
    echo $session_key
}

upgrade_image()
{
    if [ x"$1" == x"chain" ]; then
        upgrade_docker_image cess-chain $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"scheduler" ]; then
        upgrade_docker_image cess-scheduler $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"kaleido" ]; then
        upgrade_docker_image cess-kaleido $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"bucket" ]; then
        upgrade_docker_image cess-bucket $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ x"$1" == x"config-gen" ]; then
        upgrade_docker_image config-gen $2
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        tools_help
    fi
}

set_profile()
{
    local to_set=$1
    if [ x"$to_set" == x"dev" ] || [ x"$to_set" == x"test" ] || [ x"$to_set" == x"prod" ]; then
        yq -i eval ".node.profile=\"$to_set\"" $config_file
        log_success "the profile set to $to_set"
        return 0
    fi
    log_err "invalid profile value"
    return 1
}

set_extra_cmd_args()
{
    local name=$1
    shift
    local cmd_args=$@
    if [ x"$name" == x"chain" ] || [ x"$name" == x"scheduler" ] || [ x"$name" == x"bucket" ]; then
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
        log_err "invalid container name: $name, options: {chain|scheduler|bucket}"
    fi
    return 1
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
        upgrade-image)
            upgrade_image $2 $3
            ;;
        profile)
            set_profile $2
            ;;
        cmd_args)
            shift
            set_extra_cmd_args $@
            ;;
        *)
            tools_help
    esac
}
