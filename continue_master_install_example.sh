sudo mv config.ini /var/lib/mysql-cluster

sudo ndb_mgmd -f /var/lib/mysql-cluster/config.ini

sudo pkill -f ndb_mgmd

sudo systemctl daemon-reload

sudo systemctl enable ndb_mgmd

sleep 1m

sudo systemctl start ndb_mgmd

sudo ufw enable
sudo ufw allow OpenSSH
sudo ufw allow 3306

#sudo ufw allow from <SLAVE1_IP>
#sudo ufw allow from <SLAVE2_IP>
#sudo ufw allow from <SLAVE3_IP>

wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster_8.0.35-1ubuntu22.04_amd64.deb-bundle.tar

sudo mkdir install

sudo tar -xvf mysql-cluster_8.0.35-1ubuntu22.04_amd64.deb-bundle.tar -C install/