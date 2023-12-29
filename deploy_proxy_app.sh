#!/bin/bash

# Ubuntu 22.04 LTS: disable the popup "Which service should be restarted ?"
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sudo apt update
sudo apt install -y python3-pip python3-venv
sudo apt-get install -y apache2 libapache2-mod-wsgi-py3

mkdir /home/ubuntu/flaskapp && cd /home/ubuntu/flaskapp
python3 -m venv myenv

# Link to the app directory from the site-root defined in apache’s configuration
sudo ln -sT /home/ubuntu/flaskapp /var/www/html/flaskapp

sudo apt install authbind
# Configure access to port 80
sudo touch /etc/authbind/byport/80
sudo chmod 777 /etc/authbind/byport/80

source myenv/bin/activate
pip3 install flask
pip3 install sshtunnel
pip3 install mysql-connector-python

# The flask app
cat > /home/ubuntu/flaskapp/flaskapp.py << EOF
from flask import Flask, request
import json
import random
import shlex  
import subprocess
import sshtunnel
import mysql.connector
from decimal import Decimal
from datetime import datetime
app = Flask(__name__)

@app.route('/', methods=['POST',])
def proxy():
        query = request.form.get('query', type = str)
        mode = request.form.get('mode', type = str)

        master = None
        slave1 = None
        slave2 = None
        slave3 = None 
        slaves = []

        # Retrieve the cluster node private IP addresses
        with open('/home/ubuntu/cluster.json') as json_file:
           data = json.load(json_file)
           master = data['cluster']['master']
           slave1 = data['cluster']['slave_1']
           slaves.append(slave1)
           slave2 = data['cluster']['slave_2']
           slaves.append(slave2)
           slave3 = data['cluster']['slave_3']
           slaves.append(slave3)

        # Determin the node based on the mode
        chosen_node = None
        if mode == 'direct hit':
          chosen_node = master
        elif mode == 'random':
          chosen_node = random.choice(slaves)
        elif mode == 'customized':
          chosen_node = worker_with_fastest_response(slaves)
        
        sshtunnel.SSH_TIMEOUT = 10.0
        with sshtunnel.SSHTunnelForwarder(
           ssh_address_or_host = (chosen_node, 22),
           ssh_username = "ubuntu",
           ssh_pkey = "/home/ubuntu/.ssh/ms_kp_pem.pem",
           remote_bind_address = (master, 3306)
        ):
            conn= mysql.connector.connect(
               host=master,
               user='usertp3',
               password='usertp3',
               database='sakila',
               charset="utf8"
            )
            try:               
               cursor = conn.cursor(dictionary=True)
               cursor.execute(query)
               if(mode == 'direct hit'):
                  conn.commit()
               rows = cursor.fetchall()
               
               if(mode == 'direct hit'):
                  return f"<h3>{cursor.rowcount} rows affected</h3>"
               elif(cursor.rowcount > 0):
                  return f"<h3>{json.dumps(rows, indent=4, cls=SpecialEncoder)}</h3>"
               else:                  
                  return "<h3>No Result</h3>"
            except mysql.connector.Error as err:
               conn.rollback()
            finally:
               conn.close()

def exec_cmd(cmd, stderr=subprocess.STDOUT):
    args = shlex.split(cmd)
    return subprocess.check_output(args)

def ping_time(host):
    cmd = "ping -c 3 {host}".format(host=host)   
    output = exec_cmd(cmd).splitlines()[-1].decode().split('/')[-1].strip()[:-3]
    
    res = float(0)
    try:
        res = float(output)
    except ValueError:
        res = float(999999)

    return res

def worker_with_fastest_response(workers: list):
    response_times = [ping_time(worker) for worker in workers]
    idx =  min(range(len(response_times)), key=response_times.__getitem__)
    return workers[idx]

class SpecialEncoder(json.JSONEncoder):
  def default(self, obj):
    if isinstance(obj, Decimal):
      return str(obj)
    if isinstance(obj, set):
      return list(obj)
    if isinstance(obj, datetime):
      return obj.isoformat()
    return json.JSONEncoder.default(self, obj)
EOF

# Create a .wsgi file to load the app
cat > /home/ubuntu/flaskapp/flaskapp.wsgi << EOF
import sys
sys.path.insert(0, '/var/www/html/flaskapp')
sys.path.insert(0,"/home/ubuntu/flaskapp/myenv/lib/python3.10/site-packages")

from flaskapp import app as application

EOF

# Enable mod_wsgi
sudo sed -i "/DocumentRoot \/var\/www\/html/r /dev/stdin" /etc/apache2/sites-enabled/000-default.conf <<EOF
	
	WSGIDaemonProcess flaskapp threads=5 python-path=/var/www/html/flaskapp/myenv
	WSGIProcessGroup flaskapp
	WSGIApplicationGroup %%{GLOBAL}
	WSGIScriptAlias /  /var/www/html/flaskapp/flaskapp.wsgi

	<Directory flaskapp>
		Options FollowSymlinks
		AllowOverride  All
		Require all granted
		allow from all
	</Directory>
EOF

export flaskapplication=/home/ubuntu/flaskapp/flaskapp.py
authbind --deep python3 /home/ubuntu/flaskapp/flaskapp.py

sudo chmod -R +x /home/ubuntu/
sudo service apache2 restart