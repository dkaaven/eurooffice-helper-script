#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Daniel Kåven (dkaaven)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/dkaaven/eurooffice-helper-script

# Config:
DB_NAME="ds"
DB_USER="ds"
DB_PASS="$(openssl rand -base64 24)"

RABBIT_USER="eurooffice"
RABBIT_PASS="$(openssl rand -base64 24)"

REDIS_PASS="$(openssl rand -base64 24)"

JWT_SECRET="$(openssl rand -hex 32)"

CRED_FILE="/root/eurooffice.creds"

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

set -euo pipefail
color
verb_ip6
catch_errors

create_creds() {
  cat > "$CRED_FILE" <<EOF
EuroOffice Credentials
======================

PostgreSQL
----------
Database: ${DB_NAME}
Username: ${DB_USER}
Password: ${DB_PASS}

RabbitMQ
---------
Username: ${RABBIT_USER}
Password: ${RABBIT_PASS}

Redis
-----
Password: ${REDIS_PASS}

EuroOffice
----------
JWT Secret: ${JWT_SECRET}
EOF

  chmod 600 "$CRED_FILE"
}

update_system() {
  msg_info "Updating container"

  apt-get update
  apt-get -y full-upgrade

  msg_ok "Updated container"
}

install_dependencies() {
  msg_info "Installing dependencies"

  apt-get install -y \
    curl wget jq gnupg ca-certificates openssl \
    lsb-release unzip apt-transport-https

  apt-get install -y \
    fonts-dejavu \
    fonts-liberation \
    fonts-crosextra-carlito \
    fonts-opensymbol

  msg_ok "Dependencies installed"
}

install_postgresql() {
  msg_info "Installing PostgreSQL"

  apt-get install -y postgresql postgresql-contrib

  systemctl enable postgresql
  systemctl start postgresql

  msg_ok "PostgreSQL installed"
}

configure_postgresql() {
  msg_info "Configuring PostgreSQL"

  until sudo -u postgres pg_isready >/dev/null 2>&1; do
    sleep 1
  done

  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
  fi

  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
  fi

  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

  msg_ok "PostgreSQL configured"
}

install_rabbitmq() {
  msg_info "Installing RabbitMQ"

  apt-get install -y rabbitmq-server

  systemctl enable rabbitmq-server
  systemctl start rabbitmq-server

  msg_ok "RabbitMQ installed"
}

configure_rabbitmq() {
  msg_info "Configuring RabbitMQ"

  if ! rabbitmqctl list_users | awk '{print $1}' | grep -qx "${RABBIT_USER}"; then
    rabbitmqctl add_user "${RABBIT_USER}" "${RABBIT_PASS}"
  fi
  rabbitmqctl set_permissions -p / "${RABBIT_USER}" ".*" ".*" ".*"
  rabbitmqctl set_user_tags "${RABBIT_USER}" management

  msg_ok "RabbitMQ configured"
}

install_redis() {
  msg_info "Installing Redis"

  apt-get install -y redis-server

  systemctl enable redis-server
  systemctl start redis-server

  msg_ok "Redis installed"
}

configure_redis() {
  msg_info "Configuring Redis"

  local CONF="/etc/redis/redis.conf"

  [[ -f "${CONF}.bak" ]] || cp "${CONF}" "${CONF}.bak"

  if grep -q '^# *requirepass' "$CONF"; then
    sed -i "s/^# *requirepass.*/requirepass ${REDIS_PASS}/" "$CONF"
  elif grep -q '^requirepass' "$CONF"; then
    sed -i "s/^requirepass.*/requirepass ${REDIS_PASS}/" "$CONF"
  else
    echo "requirepass ${REDIS_PASS}" >> "$CONF"
  fi
  if grep -q '^bind ' "$CONF"; then
    sed -i 's/^bind .*/bind 127.0.0.1 ::1/' "$CONF"
  else
    echo "bind 127.0.0.1 ::1" >> "$CONF"
  fi

  if grep -q '^protected-mode' "$CONF"; then
    sed -i 's/^protected-mode .*/protected-mode yes/' "$CONF"
  else
    echo "protected-mode yes" >> "$CONF"
  fi

  systemctl restart redis-server

  msg_ok "Redis configured"
}

install_nginx() {
  msg_info "Installing Nginx"

  apt-get install -y nginx

  systemctl enable nginx
  systemctl start nginx

  msg_ok "Nginx installed"
}

_get_latest_deb_url() {
  curl -fsSL \
    https://api.github.com/repos/Euro-Office/DocumentServer/releases |
  jq -r '
    .[]
    | select(.prerelease == false and .draft == false)
    | .assets[]
    | select(.name | endswith("_amd64.deb"))
    | select(.name | test("(dev|beta|rc)") | not)
    | .browser_download_url
    ' | head -n1
}

preseed_eurooffice() {
  msg_info "Preseeding EuroOffice"

  cat <<EOF | debconf-set-selections
euro-office-documentserver ds/db-type select postgres
euro-office-documentserver ds/db-host string localhost
euro-office-documentserver ds/db-port string 5432
euro-office-documentserver ds/db-name string ${DB_NAME}
euro-office-documentserver ds/db-user string ${DB_USER}
euro-office-documentserver ds/db-pwd password ${DB_PASS}

euro-office-documentserver ds/rabbitmq-host string localhost
euro-office-documentserver ds/rabbitmq-proto string amqp
euro-office-documentserver ds/rabbitmq-user string ${RABBIT_USER}
euro-office-documentserver ds/rabbitmq-pwd password ${RABBIT_PASS}

euro-office-documentserver ds/jwt-enabled boolean true
euro-office-documentserver ds/jwt-secret password ${JWT_SECRET}
euro-office-documentserver ds/jwt-header string Authorization

euro-office-documentserver ds/docservice-port string 8000
euro-office-documentserver ds/example-port string 3000
euro-office-documentserver ds/ds-port string 80

euro-office-documentserver ds/plugins-enabled boolean false
euro-office-documentserver ds/wopi-enabled boolean false
euro-office-documentserver ds/cluster-mode boolean false
euro-office-documentserver ds/remove-db boolean false
EOF

  msg_ok "EuroOffice preseeded"
}

install_eurooffice() {
  msg_info "Installing EuroOffice"

  URL="$(_get_latest_deb_url)"
  echo "$URL"
  if [[ -n "$URL" ]]; then
    wget -q "$URL" -O /tmp/eurooffice.deb
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y /tmp/eurooffice.deb
  else
      msg_error "No Debian package found in the latest release."
      exit 1
  fi

  msg_ok "EuroOffice installed"
}

configure_eurooffice() {
  msg_info "Locating EuroOffice installation"

  dpkg -L eurooffice-documentserver || true

  find /etc -maxdepth 3 -iname '*euro*' 2>/dev/null
  find /opt -maxdepth 3 -iname '*euro*' 2>/dev/null
  find /usr/lib -maxdepth 3 -iname '*euro*' 2>/dev/null

  systemctl list-unit-files | grep -i euro || true

  msg_ok "Installation inspected"
}

install_systemd() {
  :
}

cleanup() {
  msg_info "Cleaning up"

  apt-get -y autoremove
  apt-get -y autoclean

  msg_ok "Cleanup completed"
}

update_system
install_dependencies
create_creds

install_postgresql
configure_postgresql

install_rabbitmq
configure_rabbitmq

install_redis
configure_redis

install_nginx

preseed_eurooffice
install_eurooffice
# configure_eurooffice

# install_systemd

cleanup

motd_ssh
customize

msg_ok "Installation finished"