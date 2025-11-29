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

function install_latest_golang() {
  pushd ~
  wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz
  tar -xf go1.25.1.linux-amd64.tar.gz -C /usr/local/
  ln -s /usr/local/go/bin/go /usr/bin
  popd
}

function install_redis-bloom() {
  pushd ~
  msg_info "Installing dependencies for redis-bloom"
  $STD apt-get install -y git make python3 cmake build-essential
  msg_ok "Installed dependencies for redis-bloom"
  git clone --recurse-submodules -j8 https://github.com/RedisBloom/RedisBloom.git -b v2.8.10
  cd RedisBloom
  ./deps/readies/bin/getpy3
  make
  find -name "redisbloom.so" -exec cp {} /var/lib/redis \;
  # create a config with ONLY these
  #sed -ie "s/appendonly yes/appendonly no/" /etc/redis/redis.conf
  #sed -ie "s/protected-mode yes/protected-mode no/" /etc/redis/redis.conf
  #echo "bind * -::*" >> /etc/redis/redis.conf
  #echo "loadmodule /var/lib/redis/redisbloom.so" >> /etc/redis/redis.conf
  popd
}

function install_mongodb() {
  VERSION=7.0

  mkdir mongodb
  pushd mongodb
  useradd -r mongodb -s /sbin/nologin
  mkdir -p /data/db
  chown -R mongodb:mongodb /data/db
  $STD apt-get install -y --upgrade gnupg curl
  curl -fsSL https://www.mongodb.org/static/pgp/server-$VERSION.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-$VERSION.gpg \
   --dearmor
  echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-$VERSION.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/$VERSION main" | sudo tee /etc/apt/sources.list.d/mongodb-org-$VERSION.list
  apt-get update
  apt-get install -y mongodb-org
  echo "[Unit]
Description=MongoDB
Documentation=
Wants=network-online.target
After=network-online.target

[Service]
User=mongodb
Group=mongodb
ExecStart=mongod --replSet rs0 --port 27017
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mongodb.service
  systemctl start mongodb

  #TODO: check that mongodb's initiate goes well
  #TODO: consensus db is not created OUAILLE ?

  for counter in {0..30}
  do
    msg_info "Waiting for mongodb to start up..."
    fail=0
    echo $counter
    mongosh --eval "rs.initiate()" || fail=1 #TODO: apparently not going well
    if [[ $fail == 0 ]]
    then
      break
    fi
    sleep 1
  done

  if [[ $fail == 1 ]]
  then
    msg_error "Mongodb failed to start"
    exit 1
  fi

  msg_ok "Initialized mongodb"

  popd
}

function install_minio() {
  mkdir minio
  pushd minio
  wget https://dl.min.io/server/minio/release/linux-amd64/minio
  chmod +x minio
  mv minio /usr/local/bin/
  useradd -r minio-user -s /sbin/nologin

  mkdir /usr/local/share/minio
  mkdir /etc/minio
  chown minio-user:minio-user /usr/local/share/minio
  chown minio-user:minio-user /etc/minio
  chown minio-user:minio-user /minio

  echo "[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
ExecStart=/usr/local/bin/minio server /minio --console-address :9999 --address :9000
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/minio.service

  systemctl start minio

  popd
  git clone https://github.com/minio/mc.git
  pushd mc
  make
  mv mc /usr/bin/minio_mc
}

function install_any-sync() {
  $STD apt-get install -y --upgrade make protobuf-compiler

  git clone https://github.com/anyproto/any-sync
  pushd any-sync
  make deps
  make proto
  popd
}

function install_any-sync-node() {
  $STD apt-get install -y --upgrade bash make

  git clone https://github.com/anyproto/any-sync-node -bv0.10.1
  pushd any-sync-node
  make deps
  make build

  cp bin/any-sync-node /usr/bin/

  echo "[Unit]
Description=Anytype-syncnode1
Documentation=
Wants=network-online.target
After=network-online.target anytype_filenode.service

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
After=network-online.target anytype_filenode.service

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
After=network-online.target anytype_filenode.service

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
  $STD apt-get install -y --upgrade bash make

  git clone https://github.com/anyproto/any-sync-filenode -v0.10.0
  pushd any-sync-filenode
  make deps
  make build

  cp bin/any-sync-filenode /usr/bin/

  echo "[Unit]
Description=Anytype-filenode
Documentation=
Wants=network-online.target
After=network-online.target anytype_coordinator.service minio.service mongodb.service redis.service

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
  $STD apt-get install -y --upgrade bash make

  git clone https://github.com/anyproto/any-sync-consensusnode -b v0.5.0
  pushd any-sync-consensusnode
  make deps
  make build

  cp bin/any-sync-consensusnode /usr/bin/

  echo "[Unit]
Description=Anytype-consensus
Documentation=
Wants=network-online.target
After=network-online.target anytype_coordinator.service anytype_node1.service anytype_node2.service anytype_node3.service

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
  $STD apt-get install -y --upgrade bash make

  git clone https://github.com/anyproto/any-sync-coordinator -bv0.8.0
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
  $STD apt-get install -y --upgrade bash make

  git clone https://github.com/anyproto/any-sync-tools
  pushd any-sync-tools
  make deps
  make build

  cd any-sync-network
  ../bin/any-sync-network create --auto

  mkdir -p /etc/anytype
  cp -r etc/* /etc/anytype

  sed -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8001/g" /etc/anytype/any-sync-filenode/config.yml
  sed -ie "/forcePathStyle.*/a \ \ \ \ credentials:" /etc/anytype/any-sync-filenode/config.yml
  sed -ie "/credentials.*/a \ \ \ \ \ \ \ \ accessKey: minioadmin" /etc/anytype/any-sync-filenode/config.yml
  sed -ie "/accessKey.*/a \ \ \ \ \ \ \ \ secretKey: minioadmin" /etc/anytype/any-sync-filenode/config.yml
  sed -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8011/g" /etc/anytype/any-sync-node-1/config.yml
  #sed -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8012/g" /etc/anytype/any-sync-node-2/config.yml
  #sed -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8013/g" /etc/anytype/any-sync-node-3/config.yml
  sed -ie "s/listenAddr: 0.0.0.0:.*/listenAddr: 0.0.0.0:8081/g" /etc/anytype/any-sync-node-1/config.yml
  #sed -ie "s/listenAddr: 0.0.0.0:.*/listenAddr: 0.0.0.0:8082/g" /etc/anytype/any-sync-node-2/config.yml
  #sed -ie "s/listenAddr: 0.0.0.0:.*/listenAddr: 0.0.0.0:8083/g" /etc/anytype/any-sync-node-3/config.yml
  sed -ie "s/addr: 0.0.0.0:.*/addr: 0.0.0.0:8005/g" /etc/anytype/any-sync-consensusnode/config.yml

  sed -ie "s/127.0.0.1/SET_TO_THE_EXTERNAL_IP/g" /etc/anytype/client.yml
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
msg_info "Installing redis-bloom"
install_redis-bloom
msg_ok "Installed redis-bloom"
msg_info "Installing any-sync-node"
install_any-sync-node
msg_ok "Installed any-sync-node"
msg_info "Installing any-sync-filenode"
install_any-sync-file-node
msg_ok "Installed any-sync-filenode"
msg_info "Installing any-sync-consensusnode"
install_any-sync-consensusnode
msg_ok "Installed any-sync-consensusnode"
msg_info "Installing any-sync-coordinator"
install_any-sync-coordinator
msg_ok "Installed any-sync-coordinator"
msg_info "Installing any-sync-tools"
install_any-sync-tools
msg_ok "Installed any-sync-tools"
msg_ok "Installed anytype"
popd

for counter in {0..10}
do
  msg_info "Waiting for minio to start up..."
  fail=0
  echo $counter
  minio_mc alias set minio http://127.0.0.1:9000 minioadmin minioadmin || fail=1 # TODO: change login/password

  if [[ $fail == 0 ]]
  then
    minio_mc mb minio/minio-bucket # TODO: rename bucket to anytype, and change configuration
    break
  fi
  sleep 1
done

if [[ $fail == 1 ]]
then
  msg_error "Minio failed to start or couldn't connect"
  exit 1
fi

# MINIO port 9000
# change ROOT_USER and PASSWORD
#sed -i "s/\"\$MINIO_ROOT_USER\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'root'/g" /etc/init.d/minio
#sed -i "s/\"\$MINIO_ROOT_PASSWORD\" = 'change-me'/\"\$MINIO_ROOT_USER\" = 'my-password'/g" /etc/init.d/minio
#sed -i "s/(MINIO_ROOT_USER)=\"change-me\"/(MINIO_ROOT_USER)=\"my-password\"/g" /etc/init.d/minio

echo "
127.0.0.1 any-sync-coordinator
127.0.0.1 any-sync-consensusnode
127.0.0.1 any-sync-filenode
127.0.0.1 any-sync-node-1
127.0.0.1 any-sync-node-2
127.0.0.1 any-sync-node-3
" >> /etc/hosts

mkdir /networkStore
chown anytype:anytype /networkStore
mkdir /anyStorage
chown anytype:anytype /anyStorage

#chown mongodb:mongodb /mongodb

systemctl daemon-reload
systemctl enable --now minio
systemctl enable --now mongodb

/anytype/any-sync-coordinator/bin/any-sync-confapply -c /etc/anytype/any-sync-coordinator/config.yml -n /etc/anytype/any-sync-coordinator/network.yml -e

# TODO: properly pass minio login info to anytype-file-node

msg_info "Consider setting net.core.rmem_max=4194304 on proxmox host"
msg_info "Consider setting net.core.wmem_max=4194304 on proxmox host"

systemctl enable --now anytype_filenode
systemctl enable --now anytype_coordinator
systemctl enable --now anytype_node-1
#systemctl enable --now anytype_node-2
#systemctl enable --now anytype_node-3
systemctl enable --now anytype_consensus

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
