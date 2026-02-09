#!/usr/bin/env bash
set -e


# get ID= and not ID_LIKE=, and trim quotes if they exist
OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d '=' -f 2)
echo "Detected OS_ID: ${OS_ID}"

# Only test OS_ID for valid strings
if [[ "${OS_ID}" =~ ^(debian|ubuntu)$ ]];
then
    echo "Supported distribution detected: ${OS_ID}"
else
    echo "This feature only supports Debian and Ubuntu based distributions. Got '${OS_ID}'.";
    exit 1;
fi

check_debian() {
    if ! [[ "9 10 11 12 13" == *"$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)"* ]];
    then
        echo "Debian $(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1) is not currently supported.";
        exit 1;
    fi
}

check_ubuntu() {
    if ! [[ "18.04 20.04 22.04 24.04" == *"$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)"* ]];
    then
        echo "Ubuntu $(grep VERSION_ID /etc/os-release | cut -d '"' -f 2) is not currently supported.";
        exit1 ;
    fi
}

if [ "${OS_ID}" = "debian" ]; then
    check_debian
    OS_RELEASE=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)
elif [ "${OS_ID}" = "ubuntu" ]; then
    check_ubuntu
    OS_RELEASE=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)
else
    echo "This feature only supports Debian and Ubuntu based distributions. Got '${OS_ID}'.";
    exit 1;
fi


if type apt-get > /dev/null 2>&1; then
    INSTALL_CMD=apt-get
elif type apk > /dev/null 2>&1; then
    INSTALL_CMD=apk
elif type microdnf > /dev/null 2>&1; then
    INSTALL_CMD=microdnf
elif type dnf > /dev/null 2>&1; then
    INSTALL_CMD=dnf
elif type yum > /dev/null 2>&1; then
    INSTALL_CMD=yum
else
    echo "(Error) Unable to find a supported package manager."
    exit 1
fi


pkg_mgr_update() {
    if [ ${INSTALL_CMD} = "apt-get" ]; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            ${INSTALL_CMD} update -y
        fi
    elif [ ${INSTALL_CMD} = "apk" ]; then
        if [ "$(find /var/cache/apk/* | wc -l)" = "0" ]; then
            echo "Running apk update..."
            ${INSTALL_CMD} update
        fi
    elif [ ${INSTALL_CMD} = "dnf" ] || [ ${INSTALL_CMD} = "yum" ]; then
        if [ "$(find /var/cache/${INSTALL_CMD}/* | wc -l)" = "0" ]; then
            echo "Running ${INSTALL_CMD} check-update ..."
            ${INSTALL_CMD} check-update
        fi
    fi
}


# Checks if packages are installed and installs them if not
check_packages() {
    if [ ${INSTALL_CMD} = "apt-get" ]; then
        if ! dpkg -s "$@" > /dev/null 2>&1; then
            pkg_mgr_update
            ${INSTALL_CMD} -y install --no-install-recommends "$@"
        fi
    elif [ ${INSTALL_CMD} = "apk" ]; then
        ${INSTALL_CMD} add \
            --no-cache \
            "$@"
    elif [ ${INSTALL_CMD} = "dnf" ] || [ ${INSTALL_CMD} = "yum" ]; then
        _num_pkgs=$(echo "$@" | tr ' ' \\012 | wc -l)
        _num_installed=$(${INSTALL_CMD} -C list installed "$@" | sed '1,/^Installed/d' | wc -l)
        if [ ${_num_pkgs} != ${_num_installed} ]; then
            pkg_mgr_update
            ${INSTALL_CMD} -y install "$@"
        fi
    elif [ ${INSTALL_CMD} = "microdnf" ]; then
        ${INSTALL_CMD} -y install \
            --refresh \
            --best \
            --nodocs \
            --noplugins \
            --setopt=install_weak_deps=0 \
            "$@"
    else
        echo "Linux distro ${ID} not supported."
        exit 1
    fi
}

check_packages curl ca-certificates odbcinst unixodbc


echo "Check ${OS_ID}/${OS_RELEASE}"
# Download the package to configure the Microsoft repo
curl -sSL -O https://packages.microsoft.com/config/$OS_ID/$OS_RELEASE/packages-microsoft-prod.deb
# Install the package
dpkg -i packages-microsoft-prod.deb
# Delete the file
rm packages-microsoft-prod.deb

apt-get update -y
ACCEPT_EULA=Y check_packages msodbcsql18 

# optional: for unixODBC development headers, kerberos library for debian-slim distributions
check_packages unixodbc-dev libgssapi-krb5-2