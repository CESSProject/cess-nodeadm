#!/bin/bash
source /opt/cess/nodeadm/scripts/utils.sh

distro_ver=$(cat /etc/issue | awk 'NF {print $2}' | cut -d . -f 1,2)
dcap_driverbin="sgx_linux_x64_driver_1.41.bin"
dcap_driverurl="https://download.01.org/intel-sgx/latest/dcap-latest/linux/distro/ubuntu$distro_ver-server/$dcap_driverbin"
isgx_driverbin="sgx_linux_x64_driver_2.11.54c9c4c.bin"                
isgx_driverurl="https://download.01.org/intel-sgx/latest/linux-latest/distro/ubuntu$distro_ver-server/$isgx_driverbin"

function try_uninstall_dirver() {
    if [ -f /opt/intel/sgxdriver/uninstall.sh ]; then
        log_info "Remove dcap/isgx driver"
        /opt/intel/sgxdriver/uninstall.sh
    fi
}

function install_dcap_sgx_driver() {
    log_info "Download dcap sgx driver"
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
    log_success "DCAP driver installed successfully"
    return 0
}

function install_oot_sgx_driver() {
    log_info "Download oot sgx driver"
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
    log_success "iSGX driver installed successfully"
    return 0
}


function install_sgx_driver() {
    ensure_root

    get_distro_name
    if [ x"$DISTRO" != x"Ubuntu" ]; then
        log_err "Your system is not supported. Kaleido currently only supports Ubuntu 18.04|20.04|22.04"
        exit 1
    fi

    if [ $distro_ver != "18.04" ] && [ $distro_ver != "20.04" ] && [ $distro_ver != "22.04" ]; then
        log_err "Your system version $distro_ver is not supported. Kaleido currently only supports Ubuntu 18.04|20.04|22.04"
        exit 1
    fi

    check_sgx
    check_oot_driver
    check_dcap_driver

    echo $oot_driver_found $dcap_driver_found

    if [[ $oot_driver_found == false && $dcap_driver_found == false ]]; then
        apt-get update > /dev/null && \
        apt-get install -y dkms > /dev/null
        # if [ $install_dcap -eq 1 ]; then
        #     install_dcap_sgx_driver
        # else
        #     install_oot_sgx_driver
        # fi
        if ! install_oot_sgx_driver; then
            return install_dcap_sgx_driver
        fi
        return 1
    fi
    return 0
}