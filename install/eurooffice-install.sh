#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Daniel Kåven (dkaaven)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/dkaaven/mailbridge-helper-script
# Inspiration: https://help.nextcloud.com/t/how-to-use-proton-mail-with-nextcloud-mail/230647

# Config:
username="protonmail"

set -euo pipefail
color
verb_ip6
catch_errors

update_system() {
  msg_info "Updating container"

  apt-get update
  apt-get -y full-upgrade

  msg_ok "Updated container"
}

install_dependencies() {
  msg_info "Installing dependencies"

  apt-get install -y curl jq

  msg_ok "Dependencies installed"
}

create_local_user() {
  msg_info "Creating local user"
  local username="$1"

  id -u "$username" &>/dev/null || \
    useradd --system --create-home --shell /usr/sbin/nologin "$username"
  msg_ok "Created user $username"
}


_get_latest_deb_url() {
  local api="https://api.github.com/repos/ProtonMail/proton-bridge/releases/latest"

  curl -fsSL "$api" |
    jq -r '.assets[]
      | select(.name | endswith("_amd64.deb"))
      | .browser_download_url'
}

install_mailbridge() {
  msg_info "Installing Proton Mail Bridge"

  local url
  url="$(_get_latest_deb_url)"

  if [[ -z "$url" ]]; then
    msg_error "Failed to determine latest Proton Mail Bridge package."
    exit 1
  fi
  wget -q --show-progress "$url" -O /tmp/protonmail-bridge.deb
  DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/protonmail-bridge.deb

  msg_ok "Proton Mail Bridge installed"
}


create_service() {
  msg_info "Creating Proton Mail Bridge Service"
  touch /etc/systemd/system/protonmail.service
  cat >/etc/systemd/system/protonmail.service <<EOF
[Unit]
Description=Proton Mail Bridge
After=network-online.target

[Service]
User=protonmail
Group=protonmail
ExecStart=/usr/bin/protonmail-bridge --noninteractive
Restart=always

[Install]
WantedBy=multi-user.target

EOF
  systemctl enable protonmail; systemctl start protonmail

  msg_ok "Service created and enabled"
}

configure_mailbridge() {
  msg_info "Configuring Proton Mail Bridge"

  # Enable and start the service
  systemctl enable --now protonmail-bridge

  # Wait for the daemon to start
  sleep 2

  msg_ok "Proton Mail Bridge service started"

  cat <<EOF

============================================================

Next step (interactive)

2. Login to your Proton account.

3. Complete MFA if prompted.

4. Create a Mail Bridge account:
    >>> info
    >>> ls
    >>> configure

5. Note the generated:
    - Username
    - Password
    - IMAP port (1143)
    - SMTP port (1025)

6. Configure Nextcloud Mail using:
    IMAP: 127.0.0.1:1143
    SMTP: 127.0.0.1:1025

============================================================

EOF
  runuser -u protonmail -- protonmail-bridge --cli
  msg_ok "Proton Mail Bridge Configured"
}


cleanup() {
  msg_info "Cleaning up"

  apt-get -y autoremove
  apt-get -y autoclean

  msg_ok "Cleanup completed"
}

update_system
install_dependencies

create_local_user "$username"

install_mailbridge
configure_mailbridge
create_service

cleanup

motd_ssh
customize

get_bootstrap_code
msg_ok "Installation finished"