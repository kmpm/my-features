#!/usr/bin/env bash


USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
BINDIR=/usr/local/bin

set -e

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

install_deps() {
    
    # Install curl
    if ! type curl > /dev/null 2>&1; then
        check_packages curl
    fi
    # Install ca-certificates or git based on package manager
    if [ "$INSTALL_CMD" = "apt-get" ]; then
        echo "Installing from OS apt repository"
        check_packages ca-certificates
    elif [ "$INSTALL_CMD" = "apk" ]; then
        echo "Installing from OS apk repository"
    else
        echo "Installing from OS yum/dnf repository"
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

if [ ! -d $BINDIR ]; then
    mkdir -p $BINDIR
fi



# install nats cli if missing
if command -v nats >/dev/null 2>&1; then
    echo "nats cli already installed. Skipping."
else
    echo "nats cli not found. Installing nats cli."
    install_deps
    curl -fsSL https://binaries.nats.dev/nats-io/natscli/nats@latest | PREFIX=$BINDIR sh 
    curl -sSfL https://get.tur.so/install.sh | bash
    which nats

    echo "Creating nats contexts"
    # create some contexts for nats
    su - ${_REMOTE_USER} << EOF
    $BINDIR/nats context save devcontainer_sys_admin --server nats://nats:4222 --user admin --password admin
    $BINDIR/nats context save devcontainer_app_app --server nats://nats:4222 --user app --password app
    $BINDIR/nats context save default --server nats://nats:4222 
    $BINDIR/nats context select default
EOF

fi

# install nsc if missing
if command -v nsc >/dev/null 2>&1; then
    echo "nsc already installed. Skipping."
    exit 1
else
    echo "nsc not found. Installing nsc."
    install_deps
    curl -fsSL https://binaries.nats.dev/nats-io/nsc/v2@latest | PREFIX=$BINDIR sh 
    if [ ! -f $BINDIR/nsc ]; then
        echo "nsc installation failed."
        exit 1
    fi
fi

