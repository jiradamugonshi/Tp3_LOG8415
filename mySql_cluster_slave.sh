#!/bin/bash

# Ubuntu 22.04 LTS: disable the popup "Which service should be restarted ?"
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

# Get NDB Data Node Binaries
wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster-community-data-node_8.0.35-1ubuntu22.04_amd64.deb

# Install a couple of dependencies
sudo apt update && sudo apt install -y libclass-methodmaker-perl

# Install the data note binary using dpkg
sudo dpkg -i mysql-cluster-community-data-node_8.0.35-1ubuntu22.04_amd64.deb

sudo rm mysql-cluster-community-data-node_8.0.35-1ubuntu22.04_amd64.deb

sudo mkdir -p /usr/local/mysql/data

# Edit ndbd.service file
sudo bash -c 'cat << EOF > /etc/systemd/system/ndbd.service
[Unit]
Description=MySQL NDB Data Node Daemon
After=network.target auditd.service

[Service]
Type=forking
ExecStart=/usr/sbin/ndbd
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'