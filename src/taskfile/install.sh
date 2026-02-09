#!/usr/bin/env bash

#set -eax
set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
BINDIR=/usr/local/bin

if command -v task > /dev/null 2>&1; then
    echo "Task is already installed. Skipping installation."
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi


if type apt-get > /dev/null 2>&1; then
    INSTALL_CMD=apt-get
    DEBIAN_FRONTEND=noninteractive
    export DEBIAN_FRONTEND
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



check_packages curl
if [ "$INSTALL_CMD" = "apt-get" ]; then
#     echo "Installing from OS apt repository"
#     curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' | bash -e
#     check_packages task
    check_packages ca-certificates
else
    echo "no supported installation method for $INSTALL_CMD, yet!"
    exit 1    
fi

#sh -e -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
curl -sSL https://taskfile.dev/install.sh -o /tmp/install_task.sh
chmod +x /tmp/install_task.sh
head /tmp/install_task.sh
/tmp/install_task.sh -d -b $BINDIR
rm /tmp/install_task.sh


if [ ! -d /etc/bash_completion.d ]; then
    mkdir -p /etc/bash_completion.d
fi

# Enable bash-completion for task
"$BINDIR/task" --completion bash | tee /etc/bash_completion.d/task > /dev/null


