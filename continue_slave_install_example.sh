sudo mv my.cnf /etc

# Start the data node
sudo ndbd

# Enable the ufw firewall and add rules
sudo ufw enable
sudo ufw allow OpenSSH
sudo ufw allow 3306

#sudo ufw allow from <MASTER_IP>
#sudo ufw allow from <SLAVE1_IP>
#sudo ufw allow from <SLAVE2_IP>

# Before we create the service, we need to kill the running server
sudo pkill -f ndbd

# Reload systemd’s manager configuration using daemon-reload
sudo systemctl daemon-reload

# Enable the service we just created
sudo systemctl enable ndbd

# Start the service
sudo systemctl start ndbd