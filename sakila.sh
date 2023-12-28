#!/bin/bash

wget https://downloads.mysql.com/docs/sakila-db.tar.gz -P ~/Downloads

sudo tar zxvf ~/Downloads/sakila-* -C /tmp

sudo mysql -u root -e "SOURCE /tmp/sakila-db/sakila-schema.sql;"
sudo mysql -u root -e "SOURCE /tmp/sakila-db/sakila-data.sql;"

sudo mysql -u root << QUERY 
CREATE USER 'usertp3'@'localhost' IDENTIFIED BY 'usertp3';
GRANT ALL PRIVILEGES on sakila.* TO 'usertp3'@'localhost' WITH GRANT OPTION;
CREATE USER 'usertp3'@'%' IDENTIFIED BY 'usertp3';
GRANT ALL PRIVILEGES on sakila.* TO 'usertp3'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
QUERY