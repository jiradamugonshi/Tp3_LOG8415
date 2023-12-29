# Install the MySQL server binary using dpkg
sudo dpkg -i install/mysql-server_8.0.35-1ubuntu22.04_amd64.deb

# Edit my.cnf file
sudo bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
# Options for mysqld process:
ndbcluster

[mysql_cluster]
# Options for NDB Cluster processes:
#ndb-connectstring=<MASTER_IP>

EOF'

# Restart the MySQL server
sudo systemctl restart mysql

# Make MySQL starts automatically when the server reboots
sudo systemctl enable mysql