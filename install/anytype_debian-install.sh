#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: mrnux
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: 

# Import Functions and Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

function install_any-sync() {
  $STD apt-get install --no-cache --upgrade make protobuf-compiler golang

  git clone https://github.com/anyproto/any-sync
  pushd any-sync
  make deps
  make proto
  popd
}

function install_any-sync-node() {
  $STD apt-get install --no-cache --upgrade bash make golang

  git clone https://github.com/anyproto/any-sync-node
  pushd any-sync-node
  make deps
  make build

  cp bin/any-sync-node /usr/bin/
  popd
}

function install_any-sync-file-node() {
  $STD apt-get install --no-cache --upgrade bash make go

  git clone https://github.com/anyproto/any-sync-filenode
  pushd any-sync-filenode
  make deps
  make build

  cp bin/any-sync-filenode /usr/bin/
  popd
}

function install_any-sync-consensusnode() {
  $STD apt-get install --no-cache --upgrade bash make golang

  git clone https://github.com/anyproto/any-sync-consensusnode
  pushd any-sync-consensusnode
  make deps
  make build

  cp bin/any-sync-consensusnode /usr/bin/
  popd

  echo '
#!/sbin/openrc-run

name="Anytype sync consensusnode"

: ${command_user:="${ANYTYPE_USER:-anytype}:${ANYTYPE_GROUP:-anytype}"}
: ${retry:=30}

command="/usr/bin/any-sync-consensusnode"
command_args="-c /etc/anytype/any-sync-consensusnode/config.yml"
command_background="yes"
# this process outputs everything to stderr
error_log="/var/log/anytype/any-sync-consensusnode.log"
pidfile="/run/$RC_SVSCNAME.pid"

depend() {
  need net
  after firewall
}
  ' > /etc/init.d/any-sync-consensusnode
}

function install_any-sync-coordinator() {
  $STD apt-get install --no-cache --upgrade bash make golang

  git clone https://github.com/anyproto/any-sync-coordinator
  pushd any-sync-coordinator
  make deps
  make build

  cp bin/any-sync-coordinator /usr/bin/
  cp bin/any-sync-confapply /usr/bin/
  popd

  echo '
#!/sbin/openrc-run

name="Anytype sync coordinator"

: ${command_user:="${ANYTYPE_USER:-anytype}:${ANYTYPE_GROUP:-anytype}"}
: ${retry:=30}

command="/usr/bin/any-sync-coordinator"
command_args="-c /etc/anytype/any-sync-coordinator/config.yml"
command_background="yes"
# this process outputs everything to stderr
error_log="/var/log/anytype/any-sync-coordinator.log"
pidfile="/run/$RC_SVSCNAME.pid"

depend() {
  need net
  after firewall
}
  ' > /etc/init.d/any-sync-coordinator
}

function install_any-sync-tools() {
  $STD apt-get install --no-cache --upgrade bash make golang

  git clone https://github.com/anyproto/any-sync-tools
  pushd any-sync-tools
  make deps
  make build

  cd any-sync-network
  ../bin/any-sync-network create --auto

  mkdir -p /etc/anytype
  cp -r etc/* /etc/anytype

  #bin/any-sync-coordinator
  #bin/any-sync-confapply
  popd
}

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get install --no-cache --upgrade make protobuf-compiler golang
msg_ok "Installed Dependencies"

install_any-sync-node
install_any-sync-file-node
install_any-sync-consensusnode
install_any-sync-coordinator
go install github.com/anyproto/any-sync-tools/any-sync-network@latest

mkdir -p /data/db

#rc-update add mongodb default # port 27001

# MINIO port 9000
# change ROOT_USER and PASSWORD
sed -i "s/\"\$MINIO_ROOT_USER\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'root'/g" /etc/init.d/minio
sed -i "s/\"\$MINIO_ROOT_PASSWORD\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'my-password'/g" /etc/init.d/minio
sed -i "s/(MINIO_ROOT_USER)=\"change-me\"/(MINIO_ROOT_USER)=\"my-password\"/g" /etc/init.d/minio

# Creating Service (if needed)
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/"${APPLICATION}".service
[Unit]
Description=${APPLICATION} Service
After=network.target

[Service]
ExecStart=[START_COMMAND]
Restart=always

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Created Service"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
rm -f "${RELEASE}".zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
