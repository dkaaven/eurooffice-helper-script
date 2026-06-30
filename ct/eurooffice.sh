#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/dkaaven/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Daniel Kåven (dkaaven)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/dkaaven/eurooffice-helper-script

APP="EuroOffice"
var_tags="${var_tags:-office}"
var_description="${var_description:-Collaborative online office suite}"

var_disk="${var_disk:-15}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"

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
echo -e "${INFO}${YW}Access EuroOffice using:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}${CL}"
