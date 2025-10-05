#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Infernux/ProxmoxVED/anytype_server/misc/build.func)
# Copyright (c) 2021-2025
# Author: mrnux
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/anytype_server/LICENSE
# Source:

APP="anytype_debian"
var_tags="${var_tags:-knowledge_database}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  useradd anytype

  $STD apt-get install redis
  #$STD apt-get install minio mongodb mongodb-tools

  #install_any-sync # needed ?

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
