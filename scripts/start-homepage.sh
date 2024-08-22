#!/usr/bin/env bash
set -E -e -o pipefail

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

start_homepage () {
    source ${NVM_DIR:?}/nvm.sh

    echo "Starting Homepage ..."
    echo

    cd /opt/homepage
    exec node server.js
}

set_umask
start_homepage
