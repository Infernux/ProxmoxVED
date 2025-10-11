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

alias apt-get="apt-get -y"

function install_latest_golang() {
  pushd ~
  wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz
  tar -xf go1.25.1.linux-amd64.tar.gz -C /usr/local/
  ln -s /usr/local/go/bin/go /usr/bin
  popd
}

function install_redis-bloom() {
  pushd ~
  $STD apt-get install git make python3 cmake build-essential
  git clone --recurse-submodules -j8 https://github.com/RedisBloom/RedisBloom.git -b v2.8.10
  cd RedisBloom
  ./deps/readies/bin/getpy3
  make
  find -name "redisbloom.so" -exec cp {} /var/lib/redis
  sed /etc/systemd/system/redis.service -ei "s/ExecStart.*/& --loadmodule /var/lib/redis/redisbloom.so"
  popd
}

function install_mongodb() {
  mkdir mongodb
  pushd mongodb
  useradd -r mongodb-user -s /sbin/nologin
  chown -R mongodb-user:mongodb-user /data/db
  mkdir -p /data/db
  $STD apt-get install --upgrade gnupg curl
  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg \
   --dearmor
  echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
  apt-get update
  apt-get install -y mongodb-org
  echo "[Unit]
Description=MongoDB
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=mongodb-user
Group=mongodb-user
ExecStart=mongod --replSet rs0 --port 27017
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mongodb.service
  systemctl start mongodb
  mongosh --eval "rs.initiate()"
  popd
}

function install_minio() {
  mkdir minio
  pushd minio
  wget https://dl.min.io/server/minio/release/linux-amd64/minio
  apt-get update
  chmod +x minio
  mv minio /usr/local/bin/
  useradd -r minio-user -s /sbin/nologin

  mkdir /usr/local/share/minio
  mkdir /etc/minio
  chown minio-user:minio-user /usr/local/share/minio
  chown minio-user:minio-user /etc/minio

  echo "[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
ExecStart=/usr/local/bin/minio server /data
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/minio.service
  popd
}

function install_any-sync() {
  $STD apt-get install --upgrade make protobuf-compiler

  git clone https://github.com/anyproto/any-sync
  pushd any-sync
  make deps
  make proto
  popd
}

function install_any-sync-node() {
  $STD apt-get install --upgrade bash make

  git clone https://github.com/anyproto/any-sync-node
  pushd any-sync-node
  make deps
  make build

  cp bin/any-sync-node /usr/bin/

  echo "[Unit]
Description=Anytype-syncnode1
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=anytype
Group=anytype
ExecStart=any-sync-node -c /etc/anytype/any-sync-node-1/config.yml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/anytype_node-1.service

  echo "[Unit]
Description=Anytype-syncnode2
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=anytype
Group=anytype
ExecStart=any-sync-node -c /etc/anytype/any-sync-node-2/config.yml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/anytype_node-2.service

  echo "[Unit]
Description=Anytype-syncnode3
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=anytype
Group=anytype
ExecStart=any-sync-node -c /etc/anytype/any-sync-node-3/config.yml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/anytype_node-3.service
  popd
}

function install_any-sync-file-node() {
  $STD apt-get install --upgrade bash make

  git clone https://github.com/anyproto/any-sync-filenode
  pushd any-sync-filenode
  make deps
  make build

  cp bin/any-sync-filenode /usr/bin/

  echo "[Unit]
Description=Anytype-filenode
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=anytype
Group=anytype
ExecStart=any-sync-filenode -c /etc/anytype/any-sync-filenode/config.yml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/anytype_filenode.service
  popd
}

function install_any-sync-consensusnode() {
  $STD apt-get install --upgrade bash make

  git clone https://github.com/anyproto/any-sync-consensusnode
  pushd any-sync-consensusnode
  make deps
  make build

  cp bin/any-sync-consensusnode /usr/bin/

  echo "[Unit]
Description=Anytype-consensus
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=anytype
Group=anytype
ExecStart=any-sync-consensusnode -c /etc/anytype/any-sync-consensusnode/config.yml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/anytype_consensus.service
  popd
}

function install_any-sync-coordinator() {
  $STD apt-get install --upgrade bash make

  git clone https://github.com/anyproto/any-sync-coordinator
  pushd any-sync-coordinator
  make deps
  make build

  cp bin/any-sync-coordinator /usr/bin/
  cp bin/any-sync-confapply /usr/bin/

  echo "[Unit]
Description=Anytype-coordinator
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=anytype
Group=anytype
ExecStart=any-sync-coordinator -c /etc/anytype/any-sync-coordinator/config.yml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/anytype_coordinator.service
  popd

}

function install_any-sync-tools() {
  $STD apt-get install --upgrade bash make

  git clone https://github.com/anyproto/any-sync-tools
  pushd any-sync-tools
  make deps
  make build

  cd any-sync-network
  ../bin/any-sync-network create --auto

  mkdir -p /etc/anytype
  cp -r etc/* /etc/anytype

  sed /etc/anytype/any-sync-filenode/config.yml -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8001/g"
  sed /etc/anytype/any-sync-node-1/config.yml -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8011/g"
  sed /etc/anytype/any-sync-node-2/config.yml -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8012/g"
  sed /etc/anytype/any-sync-node-3/config.yml -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8013/g"
  sed /etc/anytype/any-sync-consensusnode/config.yml -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8005/g"

  popd
}

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y --upgrade make protobuf-compiler git gcc redis
msg_ok "Installed Dependencies"

useradd -r anytype -s /sbin/nologin

msg_info "Installing golang"
install_latest_golang
msg_ok "Installed golang"
msg_info "Installing mongodb"
install_mongodb
msg_ok "Installed mongodb"
msg_info "Installing minio"
install_minio
msg_ok "Installed minio"
msg_info "Installing anytype"
mkdir /anytype
pushd /anytype
install_redis-bloom
install_any-sync-node
install_any-sync-file-node
install_any-sync-consensusnode
install_any-sync-coordinator
install_any-sync-tools

msg_ok "Installed anytype"
popd

#rc-update add mongodb default # port 27001

# MINIO port 9000
# change ROOT_USER and PASSWORD
sed -i "s/\"\$MINIO_ROOT_USER\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'root'/g" /etc/init.d/minio
sed -i "s/\"\$MINIO_ROOT_PASSWORD\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'my-password'/g" /etc/init.d/minio
sed -i "s/(MINIO_ROOT_USER)=\"change-me\"/(MINIO_ROOT_USER)=\"my-password\"/g" /etc/init.d/minio

echo "
127.0.0.1 any-sync-coordinator
127.0.0.1 any-sync-consensusnode
127.0.0.1 any-sync-filenode
127.0.0.1 any-sync-node-1
127.0.0.1 any-sync-node-2
127.0.0.1 any-sync-node-3
" >> /etc/hosts

systemctl daemon-reload
systemctl enable minio
systemctl enable mongodb
systemctl start minio
systemctl start mongodb

/anytype/any-sync-coordinator/bin/any-sync-confapply -c /etc/anytype/any-sync-coordinator/config.yml -n /etc/anytype/any-sync-coordinator/network.yml -e

echo "net.core.rmem_max=4194304" >> /etc/sysctl.conf
echo "net.core.wmem_max=4194304" >> /etc/sysctl.conf

systemctl enable anytype_filenode
systemctl enable anytype_coordinator
systemctl enable anytype_node-1
systemctl enable anytype_node-2
systemctl enable anytype_node-3
systemctl enable anytype_consensus
systemctl start anytype_filenode
systemctl start anytype_coordinator
systemctl start anytype_node-1
systemctl start anytype_node-2
systemctl start anytype_node-3
systemctl start anytype_consensus

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
rm -f "${RELEASE}".zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
