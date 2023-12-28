sudo mv ms_kp_pem.pem .ssh/
sudo usermod -a -G www-data ubuntu
sudo chown -R ubuntu:www-data /var/www
sudo chown ubuntu:www-data /home/ubuntu/.ssh/ms_kp_pem.pem 
chmod 440 /home/ubuntu/.ssh/ms_kp_pem.pem