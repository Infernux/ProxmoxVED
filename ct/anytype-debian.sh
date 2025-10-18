#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Infernux/ProxmoxVED/anytype_server/misc/build.func)
# Copyright (c) 2021-2025
# Author: mrnux
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/anytype_server/LICENSE
# Source:

APP="anytype-debian"
var_tags="${var_tags:-knowledge_database}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  useradd anytype

  exit 0
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
