#!/bin/bash

# Ubuntu 22.04 LTS: disable the popup "Which service should be restarted ?"
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sudo apt update
sudo apt install -y python3-pip python3-venv
sudo apt-get install -y apache2 libapache2-mod-wsgi-py3

mkdir /home/ubuntu/flaskapp && cd /home/ubuntu/flaskapp
mkdir templates
python3 -m venv myenv

# Link to the app directory from the site-root defined in apache’s configuration
sudo ln -sT /home/ubuntu/flaskapp /var/www/html/flaskapp

sudo apt install authbind
# Configure access to port 80
sudo touch /etc/authbind/byport/80
sudo chmod 777 /etc/authbind/byport/80

source myenv/bin/activate
pip3 install flask
pip3 install sqlparse
pip3 install sshtunnel

# The flask app
cat > /home/ubuntu/flaskapp/flaskapp.py << EOF
from flask import Flask, render_template, request, flash, abort
from urllib.parse import urlencode
import sqlparse
import sshtunnel
import requests
app = Flask(__name__)
app.config['SECRET_KEY'] = 'd4f9f7cb6f3e93020a328d4187863aeed53a3078ac774f16'

@app.route('/', methods=('GET', 'POST'))
def base():
        modes = ['Direct hit', 'Random', 'Customized']
        dml_types = ['SELECT', 'INSERT', 'UPDATE', 'DELETE']

        if request.method == 'POST':
          query = request.form['query']
          mode = request.form['modes']

          if not query:
            flash('Query is required!')
          else:
            statements = sqlparse.split(query)
            # Check if there is more than one statement
            if(len(statements) > 1):
               abort(400, "More than one statement")
            statement = sqlparse.parse(statements[0])[0]
            # Check if the statement is a DML
            if(statement.get_type() not in dml_types):
               abort(400, "Only SELECT, INSERT, UPDATE or DELETE are authorized")
            
            # Check if there is a Where clause and the DML statement is a Delete or an Update
            isWhere = any(map(lambda token: isinstance(token, sqlparse.sql.Where), statement))
            if(statement.get_type() in dml_types[2:] and not isWhere):
               abort(400, "No WHERE clause in DELETE or UPDATE actions") 

            # Get the index of the Where clause
            idx = 0
            try:
               idx = list(map(lambda token: isinstance(token, sqlparse.sql.Where), statement)).index(True)
            except ValueError:
               idx = -1

            # Parse the Where clause
            if(idx > -1):
               where = statement[idx]
               extracted_keys = get_tokens(where)
               # Check the Where clause is not destructive like "Where 1 = 1"
               if(statement.get_type() in dml_types[2:] and any(map(lambda item: isinstance(item, bool) and item, extracted_keys))):
                  abort(400, "The query seems to be destructive")

            # Determin the appropriate mode based on the DML type and the selected mode
            if(statement.get_type() in dml_types[1:]):
               mode = 'direct hit'
            else:
               mode = 'customized' if mode.lower() == 'customized' else 'random'

            sshtunnel.SSH_TIMEOUT = 10.0
            # Forward the request to the trusted host
            with sshtunnel.SSHTunnelForwarder(
               ssh_address_or_host = ("%s", 22),
               ssh_username = "ubuntu",
               ssh_pkey = "/home/ubuntu/.ssh/ms_kp_pem.pem",
               remote_bind_address = ("%s", 80)               
            ) as tunnel:
               try:
                  params = urlencode({'query': query, 'mode': mode})
                  headers = {"Content-type": "application/x-www-form-urlencoded", "Accept": "text/plain"}
                  response = requests.post('http://%s/', data=params, headers=headers)  
                  return f"<h3>{response.text}</h3>"
               except Exception as e:
                  abort(500)              

        return render_template('query.html', modes=modes)

def intTryParse(value):
    try:
        return int(value), True
    except ValueError:
        return value, False

def get_tokens(where):
  identifier = None
  extracted_keys = []
  
  for i in where.tokens:
    try:
      name = i.get_real_name()      
      
      if name and isinstance(i, sqlparse.sql.Identifier):
        name = i.get_real_name()
        identifier = i
      
      elif identifier and isinstance(i, sqlparse.sql.Parenthesis):
        extracted_keys.append((identifier.get_real_name(), i.value))
        
      elif i and "in" not in i.value.lower() and "or" not in i.value.lower() and isinstance(i, sqlparse.sql.Comparison):            
        if "!=" in i.value:
            key,value = i.value.split("!=")[0].strip(), i.value.split("!=")[1].strip()
            k_parsed, parse_k_result = intTryParse(key)
            v_parsed, parse_v_result = intTryParse(value)
            if(parse_k_result and parse_v_result):
               extracted_keys.append(k_parsed != v_parsed)
            else:
               extracted_keys.append(k_parsed != v_parsed)

        elif ">=" in i.value:
            key,value = i.value.split(">=")[0].strip(), i.value.split(">=")[1].strip()
            k_parsed, parse_k_result = intTryParse(key)
            v_parsed, parse_v_result = intTryParse(value)
            if(parse_k_result and parse_v_result):
               extracted_keys.append(k_parsed >= v_parsed)
            else:
               extracted_keys.append((k_parsed, v_parsed))
        
        elif "<=" in i.value:
            key,value = i.value.split("<=")[0].strip(), i.value.split("<=")[1].strip()
            k_parsed, parse_k_result = intTryParse(key)
            v_parsed, parse_v_result = intTryParse(value)
            if(parse_k_result and parse_v_result):
               extracted_keys.append(k_parsed <= v_parsed)
            else:
               extracted_keys.append((k_parsed, v_parsed))

        elif "=" in i.value:
            key,value = i.value.split("=")[0].strip(), i.value.split("=")[1].strip()
            k_parsed, parse_k_result = intTryParse(key)
            v_parsed, parse_v_result = intTryParse(value)
            if(parse_k_result and parse_v_result):
               extracted_keys.append(k_parsed == v_parsed)
            else:
               extracted_keys.append(k_parsed == v_parsed)

        elif ">" in i.value:
            key,value = i.value.split(">")[0].strip(), i.value.split(">")[1].strip()
            k_parsed, parse_k_result = intTryParse(key)
            v_parsed, parse_v_result = intTryParse(value)
            if(parse_k_result and parse_v_result):
               extracted_keys.append(k_parsed > v_parsed)
            else:
               extracted_keys.append((k_parsed, v_parsed))
        
        elif "<" in i.value:
            key,value = i.value.split("<")[0].strip(), i.value.split("<")[1].strip()
            k_parsed, parse_k_result = intTryParse(key)
            v_parsed, parse_v_result = intTryParse(value)
            if(parse_k_result and parse_v_result):
               extracted_keys.append(k_parsed < v_parsed)
            else:
               extracted_keys.append((k_parsed, v_parsed))
            
        elif "not like" in i.value.lower():
            key,value = i.value.lower().split("not like")[0].strip(), i.value.lower().split("not like")[1].strip()
            if(key.startswith('\'')):
                extracted_keys.append(True)
            else:
                extracted_keys.append((key.upper(), value))

        elif "like" in i.value.lower():
            key,value = i.value.lower().split("like")[0].strip(), i.value.lower().split("like")[1].strip()
            if(key.startswith('\'')):
                extracted_keys.append(True)
            else:
                extracted_keys.append((key.upper(), value))
        
      else:
        extracted_keys.extend(get_tokens(i))
    
    except Exception as error:
      pass
    
  return extracted_keys

EOF

# Create the query view template
cat > /home/ubuntu/flaskapp/templates/query.html << EOF
{%% extends 'base.html' %%}

{%% block content %%}
    <h1>{%% block title %%} Execute a sql query {%% endblock %%}</h1>
    <form method="post"> 
		<label for="mode">Mode</label>
        <br>
        <select name="modes">
			<option value="{{modes[0]}}" selected>{{modes[0]}}</option>
			{%% for mode in modes[1:] %%}
            	<option value="{{ mode }}">{{ mode }}</option>
          	{%% endfor %%}     
        </select>  
		<br>

        <label for="query">SQL Query</label>
        <br>
        <textarea name="query"
                  rows="15"
                  cols="60"
                  >{{ request.form['query'] }}</textarea>
        <br>
        <button type="submit">Submit</button>
    </form>
{%% endblock %%}

EOF

# Create the base view template
cat > /home/ubuntu/flaskapp/templates/base.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{%% block title %%} {%% endblock %%} - FlaskApp</title>
    <style> 
        .alert {
            padding: 20px;
            margin: 5px;
            color: #970020;
            background-color: #ffd5de;
        }

    </style>
</head>
<body>    
    <div class="content">
        {%% for message in get_flashed_messages() %%}
            <div class="alert">{{ message }}</div>
        {%% endfor %%}
        {%% block content %%} {%% endblock %%}
    </div>
</body>
</html>

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