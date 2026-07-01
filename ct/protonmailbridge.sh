#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/dkaaven/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Daniel Kåven (dkaaven)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/dkaaven/eurooffice-helper-script

APP="ProtonMailBridge"
var_tags="${var_tags:-mail}"
var_description="${var_description:-Proton Mail Bridge for IMAP/SMTP access}"

var_disk="${var_disk:-20}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-2048}"

var_os="${var_os:-debian}"
var_version="${var_version:-13}"

var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  msg_error "Automatic updates are not yet implemented."
  exit 1
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
