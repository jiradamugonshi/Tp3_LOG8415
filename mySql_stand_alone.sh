#!/bin/bash

# Ubuntu 22.04 LTS: disable the popup "Which service should be restarted ?"
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sudo apt update

# Install Mysql server
sudo apt-get install mysql-server -y

# Install Sysbench
sudo apt-get install sysbench -y