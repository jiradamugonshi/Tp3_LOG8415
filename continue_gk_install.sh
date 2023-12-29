sudo mv ms_kp_pem.pem .ssh/
# Add the ubuntu user to the apache2 group
sudo usermod -a -G www-data ubuntu
# Change the group ownership of the /var/www directory and its contents to the apache2 group
sudo chown -R ubuntu:www-data /var/www
# Change the group owner of the pem key to the apache2 group
sudo chown ubuntu:www-data /home/ubuntu/.ssh/ms_kp_pem.pem
# Change the group rights of the pem key
chmod 440 /home/ubuntu/.ssh/ms_kp_pem.pem