#!/bin/bash
source /opt/cess/nodeadm/scripts/utils.sh

ensure_root

get_distro_name
if [ x"$DISTRO" != x"Ubuntu" ]; then
    log_err "Your system is not supported. Kaleido currently only supports Ubuntu 18.04/Ubuntu 20.04"
    exit 1
fi

is_18=$(cat /etc/issue | grep 18.04)
is_20=$(cat /etc/issue | grep 20.04)

if [ x"$is_18" != x"" ]; then
    dcap_driverurl="https://download.01.org/intel-sgx/latest/dcap-latest/linux/distro/ubuntu18.04-server/sgx_linux_x64_driver_1.41.bin"
    dcap_driverbin="sgx_linux_x64_driver_1.41.bin"
    isgx_driverurl="https://download.01.org/intel-sgx/latest/linux-latest/distro/ubuntu18.04-server/sgx_linux_x64_driver_2.11.054c9c4c.bin"
    isgx_driverbin="sgx_linux_x64_driver_2.11.054c9c4c.bin"
elif [ x"$is_20" != x"" ]; then
    dcap_driverurl="https://download.01.org/intel-sgx/latest/dcap-latest/linux/distro/ubuntu20.04-server/sgx_linux_x64_driver_1.41.bin"
    dcap_driverbin="sgx_linux_x64_driver_1.41.bin"
    isgx_driverurl="https://download.01.org/intel-sgx/latest/linux-latest/distro/ubuntu20.04-server/sgx_linux_x64_driver_2.11.054c9c4c.bin"
    isgx_driverbin="sgx_linux_x64_driver_2.11.054c9c4c.bin"
else
    log_err "Your system is not supported. Kaleido currently only supports Ubuntu 18.04/Ubuntu 20.04"
    exit 1
fi

function try_uninstall_dirver() {
    if [ -f /opt/intel/sgxdriver/uninstall.sh ]; then
        log_info "Remove dcap/isgx driver"
        /opt/intel/sgxdriver/uninstall.sh
    fi
}

function install_dcap() {
    log_info "Download dcap driver"
    for i in $(seq 0 4); do
        wget $dcap_driverurl -O /tmp/$dcap_driverbin
        if [ $? -ne 0 ]; then
            log_err "Download isgx dirver failed, try again!"
        else
            break
        fi
    done

    if [ -f /tmp/$dcap_driverbin ]; then
        log_info "Give dcap driver executable permission"
        chmod +x /tmp/$dcap_driverbin
    else
        log_err "The DCAP driver was not successfully downloaded, please check your network!"
        return 1
    fi

    try_uninstall_dirver

    log_info "Installing dcap driver"
    /tmp/$dcap_driverbin
    if [ $? -ne 0 ]; then
        log_err "Failed to install the DCAP driver, please check the driver's installation logs!"
        return 1
    else
        log_success "Delete temporary files"
        rm /tmp/$dcap_driverbin
    fi

    return 0
}

function install_isgx() {
    log_info "Download isgx driver"
    for i in $(seq 0 4); do
        wget $isgx_driverurl -O /tmp/$isgx_driverbin
        if [ $? -ne 0 ]; then
            log_err "Download isgx dirver failed"
        else
            break
        fi
    done

    if [ -f /tmp/$isgx_driverbin ]; then
        log_info "Give isgx driver executable permission"
        chmod +x /tmp/$isgx_driverbin
    else
        log_err "The isgx driver was not successfully downloaded, please check your network!"
        return 1
    fi

    try_uninstall_dirver

    log_info "Installing isgx driver"
    /tmp/$isgx_driverbin
    if [ $? -ne 0 ]; then
        log_err "Failed to install the isgx driver, please check the driver installation logs!"
        return 1
    else
        log_success "Deleteted temporary files"
        rm /tmp/$isgx_driverbin
    fi

    return 0
}

function try_install_dcap_else_isgx() {
    install_dcap

    if [ $? -ne 0 ]; then
        log_info "try install isgx driver"
        install_isgx
        if [ $? -ne 0 ]; then
            log_err "Failed to install the DCAP and the isgx driver, please check the driver installation logs!"
            exit 1
        fi
    fi
}

case "$1" in
dcap)
    install_dcap
    ;;
isgx)
    install_isgx
    ;;
*)
    try_install_dcap_else_isgx
    ;;
esac

ensure_installed_sgx_driver
if [ $? -ne 0 ]; then
    exit 1
fi
