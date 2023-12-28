#!/bin/bash
KEY_NAME=ms_kp_pem.pem

# Configure AWS Cluster
output=$(python aws_setup.py "$@")
arr=(${output//:/ })

MASTER_DNS_NAME=${arr[0]}
MASTER_HOSTNAME=${arr[1]}
MASTER_PRIVATE_IP=${arr[2]}

SLAVE_1_DNS_NAME=${arr[3]}
SLAVE_1_HOSTNAME=${arr[4]}
SLAVE_1_PRIVATE_IP=${arr[5]}

SLAVE_2_DNS_NAME=${arr[6]}
SLAVE_2_HOSTNAME=${arr[7]}
SLAVE_2_PRIVATE_IP=${arr[8]}

SLAVE_3_DNS_NAME=${arr[9]}
SLAVE_3_HOSTNAME=${arr[10]}
SLAVE_3_PRIVATE_IP=${arr[11]}

PROXY_DNS_NAME=${arr[12]}
STANDALONE_DNS_NAME=${arr[13]}
GATEKEEPER_DNS_NAME=${arr[14]}

# Create config file
cat > config.ini << EOF
[ndb_mgmd]
hostname=$MASTER_PRIVATE_IP
datadir=/var/lib/mysql-cluster
nodeid=1

[ndbd default]
NoOfReplicas=3
ServerPort=11860
DataMemory=2048M
IndexMemory=384M

[ndbd]
hostname=$SLAVE_1_PRIVATE_IP
nodeid=2
datadir=/usr/local/mysql/data

[ndbd]
hostname=$SLAVE_2_PRIVATE_IP
nodeid=3
datadir=/usr/local/mysql/data

[ndbd]
hostname=$SLAVE_3_PRIVATE_IP
nodeid=4
datadir=/usr/local/mysql/data

[mysqld]
hostname=$MASTER_PRIVATE_IP
EOF

cat > my.cnf << EOF
[mysql_cluster]
ndb-connectstring=$MASTER_PRIVATE_IP

EOF

cat > cluster.json << EOF
{
    "cluster": {
        "master": "$MASTER_PRIVATE_IP",
        "slave_1": "$SLAVE_1_PRIVATE_IP",
        "slave_2": "$SLAVE_2_PRIVATE_IP",
        "slave_3": "$SLAVE_3_PRIVATE_IP"
    }
}

EOF

rm benchmark.json
cat > benchmark.json << EOF
{
    "master": "$MASTER_DNS_NAME",
    "standalone": "$STANDALONE_DNS_NAME"      
}

EOF

cp continue_master_install_example.sh continue_master_install.sh
sed -i "s@#sudo ufw allow from <SLAVE1_IP>@sudo ufw allow from $SLAVE_1_PRIVATE_IP@" continue_master_install.sh
sed -i "s@#sudo ufw allow from <SLAVE2_IP>@sudo ufw allow from $SLAVE_2_PRIVATE_IP@" continue_master_install.sh
sed -i "s@#sudo ufw allow from <SLAVE3_IP>@sudo ufw allow from $SLAVE_3_PRIVATE_IP@" continue_master_install.sh

cp continue2_master_install_example.sh continue2_master_install.sh
sed -i "s@#ndb-connectstring=<MASTER_IP>@ndb-connectstring=$MASTER_PRIVATE_IP@" continue2_master_install.sh

cp continue_slave_install_example.sh continue_slave1_install.sh
sed -i "s@#sudo ufw allow from <MASTER_IP>@sudo ufw allow from $MASTER_PRIVATE_IP@" continue_slave1_install.sh
sed -i "s@#sudo ufw allow from <SLAVE1_IP>@sudo ufw allow from $SLAVE_2_PRIVATE_IP@" continue_slave1_install.sh
sed -i "s@#sudo ufw allow from <SLAVE2_IP>@sudo ufw allow from $SLAVE_3_PRIVATE_IP@" continue_slave1_install.sh

cp continue_slave_install_example.sh continue_slave2_install.sh
sed -i "s@#sudo ufw allow from <MASTER_IP>@sudo ufw allow from $MASTER_PRIVATE_IP@" continue_slave2_install.sh
sed -i "s@#sudo ufw allow from <SLAVE1_IP>@sudo ufw allow from $SLAVE_1_PRIVATE_IP@" continue_slave2_install.sh
sed -i "s@#sudo ufw allow from <SLAVE2_IP>@sudo ufw allow from $SLAVE_3_PRIVATE_IP@" continue_slave2_install.sh

cp continue_slave_install_example.sh continue_slave3_install.sh
sed -i "s@#sudo ufw allow from <MASTER_IP>@sudo ufw allow from $MASTER_PRIVATE_IP@" continue_slave3_install.sh
sed -i "s@#sudo ufw allow from <SLAVE1_IP>@sudo ufw allow from $SLAVE_1_PRIVATE_IP@" continue_slave3_install.sh
sed -i "s@#sudo ufw allow from <SLAVE2_IP>@sudo ufw allow from $SLAVE_2_PRIVATE_IP@" continue_slave3_install.sh

sleep 5m

sed -i -e 's/\r$//' cluster.json
sed -i -e 's/\r$//' config.ini
sed -i -e 's/\r$//' my.cnf

sed -i -e 's/\r$//' continue_master_install.sh
sed -i -e 's/\r$//' continue2_master_install.sh
sed -i -e 's/\r$//' continue_slave1_install.sh
sed -i -e 's/\r$//' continue_slave2_install.sh
sed -i -e 's/\r$//' continue_slave3_install.sh

sed -i -e 's/\r$//' sakila.sh

scp -i $KEY_NAME $KEY_NAME ubuntu@$GATEKEEPER_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue_gk_install.sh ubuntu@$GATEKEEPER_DNS_NAME:/home/ubuntu

scp -i $KEY_NAME cluster.json ubuntu@$PROXY_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME $KEY_NAME ubuntu@$PROXY_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue_proxy_install.sh ubuntu@$PROXY_DNS_NAME:/home/ubuntu

scp -i $KEY_NAME sakila.sh ubuntu@$STANDALONE_DNS_NAME:/home/ubuntu

scp -i $KEY_NAME config.ini ubuntu@$MASTER_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue_master_install.sh ubuntu@$MASTER_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue2_master_install.sh ubuntu@$MASTER_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME sakila.sh ubuntu@$MASTER_DNS_NAME:/home/ubuntu

scp -i $KEY_NAME my.cnf ubuntu@$SLAVE_1_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue_slave1_install.sh ubuntu@$SLAVE_1_DNS_NAME:/home/ubuntu

scp -i $KEY_NAME my.cnf ubuntu@$SLAVE_2_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue_slave2_install.sh ubuntu@$SLAVE_2_DNS_NAME:/home/ubuntu

scp -i $KEY_NAME my.cnf ubuntu@$SLAVE_3_DNS_NAME:/home/ubuntu
scp -i $KEY_NAME continue_slave3_install.sh ubuntu@$SLAVE_3_DNS_NAME:/home/ubuntu

rm cluster.json
rm config.ini
rm my.cnf

rm continue_master_install.sh
rm continue2_master_install.sh
rm continue_slave1_install.sh
rm continue_slave2_install.sh
rm continue_slave3_install.sh