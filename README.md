# Tp3_LOG8415
1. Run **automation_script.sh** to run the code on the EC2 instances.
2. Connect to the gatekeeper and run **continue_gk_install.sh**
3. Connect to the proxy and run **continue_proxy_install.sh**
4. Connect to the master and run **continue_master_install.sh**
5. Check ndb_mgmd status **sudo systemctl status ndb_mgmd**
6. Connect to each slave and run **continue_slaveX_install.sh**
7. Check ndbd status **sudo systemctl status ndbd**
8. Connect again to the master and run this command
**sudo dpkg -i install/mysql-cluster-community-server_8.0.35-1ubuntu22.04_amd64.deb**
When installing mysql-cluster-community-server, a configuration prompt should appear, asking you to set a password for the root account of your MySQL database.
9. Run **continue2_master_install.sh**
10. Verify MySQL Cluster Installation
a- Run **sudo mysql -u root -p** Then **SHOW ENGINE NDB STATUS \G**
b- run **ndb_mgm** Then **SHOW**
11. Run **sakila.sh** both on the master and the stand alone node to install sakila database.
