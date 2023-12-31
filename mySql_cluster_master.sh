#!/bin/bash

# Ubuntu 22.04 LTS: disable the popup "Which service should be restarted ?"
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

# Get the NDB Management Server
wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster-community-management-server_8.0.35-1ubuntu22.04_amd64.deb

# Install ndb_mgmd using dpkg
sudo dpkg -i mysql-cluster-community-management-server_8.0.35-1ubuntu22.04_amd64.deb

# Create the /var/lib/mysql-cluster directory where this file will reside
sudo mkdir /var/lib/mysql-cluster

# Edit the ndb_mgmd.service file
sudo bash -c 'cat << EOF > /etc/systemd/system/ndb_mgmd.service
[Unit]
Description=MySQL NDB Cluster Management Server
After=network.target auditd.service

[Service]
Type=forking
ExecStart=/usr/sbin/ndb_mgmd -f /var/lib/mysql-cluster/config.ini
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'

# Get the MySQL Cluster Server binary
wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster_8.0.35-1ubuntu22.04_amd64.deb-bundle.tar

sudo mkdir install

sudo tar -xvf mysql-cluster_8.0.35-1ubuntu22.04_amd64.deb-bundle.tar -C install/

# Install a couple of dependencies
sudo apt update && sudo apt install -y libaio1 libmecab2

# Install the MySQL Cluster dependencies
sudo dpkg -i install/mysql-common_8.0.35-1ubuntu22.04_amd64.deb
sudo dpkg -i install/mysql-cluster-community-client-plugins_8.0.35-1ubuntu22.04_amd64.deb
sudo dpkg -i install/mysql-cluster-community-client-core_8.0.35-1ubuntu22.04_amd64.deb
sudo dpkg -i install/mysql-cluster-community-client_8.0.35-1ubuntu22.04_amd64.deb
sudo dpkg -i install/mysql-client_8.0.35-1ubuntu22.04_amd64.deb
sudo dpkg -i install/mysql-cluster-community-server-core_8.0.35-1ubuntu22.04_amd64.deb

# Install Sysbench
sudo apt-get install sysbench -y