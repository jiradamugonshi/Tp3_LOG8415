sudo mv my.cnf /etc

sudo ndbd

sudo ufw enable
sudo ufw allow OpenSSH
sudo ufw allow 3306

#sudo ufw allow from <MASTER_IP>
#sudo ufw allow from <SLAVE1_IP>
#sudo ufw allow from <SLAVE2_IP>

sudo pkill -f ndbd

sudo systemctl daemon-reload

sudo systemctl enable ndbd

sudo systemctl start ndbd