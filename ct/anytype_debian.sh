#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Infernux/ProxmoxVED/misc/build.func)
# Copyright (c) 2021-2025
# Author: mrnux
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/dani-garcia/vaultwarden

APP="Anytype server"
var_tags="${var_tags:-password-manager}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-1}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

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

function update_script() {
  useradd anytype

  msg_info "Updating Alpine Packages"
  $STD apk -U upgrade
  msg_ok "Updated Alpine Packages"

  # Add mongodb repositories
  echo 'http://dl-cdn.alpinelinux.org/alpine/v3.9/main' >> /etc/apk/repositories
  echo 'http://dl-cdn.alpinelinux.org/alpine/v3.9/community' >> /etc/apk/repositories
  apk update

  #echo http://dl-4.alpinelinux.org/alpine/edge/testing/ >> /etc/apk/repositories
  #apk update
  #apt-get install ruby shadow less make gcc libc-dev
  #gem install puppet racc

  $STD apt-get install --no-cache --upgrade redis minio mongodb mongodb-tools

  #install_any-sync # needed ?
  install_any-sync-node
  install_any-sync-file-node
  install_any-sync-consensusnode
  install_any-sync-coordinator
  go install github.com/anyproto/any-sync-tools/any-sync-network@latest

  mkdir -p /data/db

  rc-update add mongodb default # port 27001

  # MINIO port 9000
  # change ROOT_USER and PASSWORD
  sed -i "s/\"\$MINIO_ROOT_USER\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'root'/g" /etc/init.d/minio
  sed -i "s/\"\$MINIO_ROOT_PASSWORD\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'my-password'/g" /etc/init.d/minio
  sed -i "s/(MINIO_ROOT_USER)=\"change-me\"/(MINIO_ROOT_USER)=\"my-password\"/g" /etc/init.d/minio

  systemctl enable minio
  systemctl enable redis
  systemctl enable any-sync-coordinator
  systemctl enable any-sync-consensusnode

  # should wait for minio to be up
  # bootstrap ?
  go install github.com/minio/mc@latest
  /root/go/bin/mc mb minio/minio-bucket

  any-sync-coordinator/bin/any-sync-confapply -c /etc/anytype/any-sync-coordinator/config.yml -n /etc/anytype/any-sync-coordinator/network.yml -e
  #any-sync-filenode/bin/any-sync-filenode -c /etc/anytype/any-sync-filenode/config.yml

  echo "
127.0.0.1 any-sync-coordinator  localhost.localdomain
127.0.0.1 any-sync-consensusnode  localhost.localdomain
  " >> /etc/hosts

  # need
  # redis
  # consensus-node
  # coordinator
  # sync-node x 3
  # filenode
  # netcheck
  # minio
  # mongo

  exit 0
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
