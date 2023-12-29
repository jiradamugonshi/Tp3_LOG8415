import paramiko
import time
import json
from scp import SCPClient


# The set of commands to execute against the cluster
def sysbench_cluster():
    return """
#!/bin/bash

sudo rm cluster-benchmark.txt 2> /dev/null

sudo sysbench  oltp_read_write --threads=6 --events=10000 --tables=1 --table-size=1000000 --db-driver=mysql --mysql-db=sakila --mysql-host=localhost --mysql-user=root --mysql_storage_engine=ndbcluster prepare

sudo sysbench  oltp_read_write --threads=6 --events=10000 --tables=1 --table-size=1000000 --db-driver=mysql --mysql-db=sakila --mysql-host=localhost --mysql-user=root --mysql_storage_engine=ndbcluster run > cluster-benchmark.txt

sudo sysbench  oltp_read_write --tables=1 --db-driver=mysql --mysql-db=sakila --mysql-host=localhost --mysql-user=root --mysql_storage_engine=ndbcluster cleanup

EOF
"""

# The set of commands to execute against the stand alone
def sysbench_stand_alone():
    return """
#!/bin/bash

sudo rm stand-alone-benchmark.txt 2> /dev/null

sudo sysbench  oltp_read_write --threads=6 --events=10000 --tables=1 --table-size=1000000 --db-driver=mysql --mysql-db=sakila --mysql-host=localhost --mysql-user=root --mysql_storage_engine=innodb  prepare

sudo sysbench  oltp_read_write --threads=6 --events=10000 --tables=1 --table-size=1000000 --db-driver=mysql --mysql-db=sakila --mysql-host=localhost --mysql-user=root --mysql_storage_engine=innodb  run > stand-alone-benchmark.txt

sudo sysbench  oltp_read_write --tables=1 --db-driver=mysql --mysql-db=sakila --mysql-host=localhost --mysql-user=root --mysql_storage_engine=innodb  cleanup

EOF
"""

# make ssh connect to the specified DNS name
def ssh_connect(ssh, dnsName, retries, keyName):
    if retries > 3:
        return False
    
    privatekey = paramiko.RSAKey.from_private_key_file(keyName) 
    
    try:
        retries += 1
        print('SSH to the instance: {}'.format(dnsName))
        ssh.connect(hostname=dnsName, username="ubuntu", pkey=privatekey)
        return True
    except Exception as e:
        print(e)
        time.sleep(3)
        print('Retrying SSH connection to {}'.format(dnsName))
        ssh_connect(ssh, dnsName, retries, keyName)

# launch the benchmarking on the specified DNS name
def launch_benchmark(dnsName, sysbench, keyName, benchFileName):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_connect(ssh, dnsName, 0, keyName)
   
    stdin, stdout, stderr = ssh.exec_command(sysbench()) 

    time.sleep(60)

    # transfer the generated file to the local current folder
    scp = SCPClient(ssh.get_transport())
    scp.get('/home/ubuntu/' + benchFileName, './')  

    scp.close()
    ssh.close()

def main():
    KEY_NAME = "ms_kp_pem.pem"

    with open('benchmark.json') as json_file:
           data = json.load(json_file)
           cluster_master_dns = data['master']
           stand_alone_dns = data['standalone']          

    print("The MySQL Cluster Benchmark Starts")
    launch_benchmark(cluster_master_dns, sysbench_cluster, KEY_NAME, 'cluster-benchmark.txt')
    print("The MySQL Cluster Benchmark Ends")

    print("The Stand-Alone Benchmark Starts")
    launch_benchmark(stand_alone_dns, sysbench_stand_alone, KEY_NAME, 'stand-alone-benchmark.txt')
    print("The Stand-Alone Benchmark Ends")

if __name__ == "__main__":
    main()