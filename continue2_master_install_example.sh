sudo dpkg -i install/mysql-server_8.0.35-1ubuntu22.04_amd64.deb

sudo bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
# Options for mysqld process:
ndbcluster

[mysql_cluster]
# Options for NDB Cluster processes:
#ndb-connectstring=<MASTER_IP>

EOF'

sudo systemctl restart mysql

sudo systemctl enable mysql