import os
import boto3
from botocore.exceptions import ClientError

ec2 = boto3.resource('ec2')
ec2_client = boto3.client('ec2')

def get_subnet_id(zone):
    # get the subnet_id based on the availability-zone
    subnetId = ec2_client.describe_subnets(
        Filters = [
        {
            'Name': 'availability-zone',
            'Values': [
                 zone
            ]
        },
        ])['Subnets'][0]['SubnetId']
    return subnetId

def create_key_pair(name):
    # if key_pair does not exist, create one
    try:
        ec2_client.describe_key_pairs(KeyNames=[name])
    except ClientError as e:
        ec2.create_key_pair(KeyName=name)
    return ec2_client.describe_key_pairs(KeyNames=[name], IncludePublicKey=True)['KeyPairs'][0]['PublicKey']

def create_security_group(name, desc, vpc_id, ip_permissions=None):
    # if security group does not exist, create one
    try:
        sg = ec2_client.describe_security_groups(GroupNames=[name])['SecurityGroups'][0]
    except ClientError as e:
        ec2.create_security_group(GroupName=name, Description = desc, VpcId=vpc_id)

        sg = ec2_client.describe_security_groups(GroupNames=[name])['SecurityGroups'][0]

        # add rules for security
        if ip_permissions is None:           
            ec2_client.authorize_security_group_ingress(
                GroupId = sg['GroupId'],
                IpPermissions = [                
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
                },            
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 1186,
                    'ToPort': 1186,
                    'UserIdGroupPairs': [{'GroupId': sg['GroupId']}]   
                },                
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 11860,
                    'ToPort': 11860,
                    'UserIdGroupPairs': [{'GroupId': sg['GroupId']}]               
                },                 
                ])
        else:
             ec2_client.authorize_security_group_ingress(
                GroupId = sg['GroupId'],
                IpPermissions = ip_permissions
            )

    return sg

def create_cluster(count, instance_type, key_name, zone, subnet, security_group, user_script, name_tag):
    # create the cluster
    cluster = ec2.create_instances(
        ImageId = 'ami-0fc5d935ebf8bc3bc',
        MinCount = count,
        MaxCount = count,
        InstanceType = instance_type,
        KeyName = key_name,
        Placement = {
            'AvailabilityZone': zone
        },
        SubnetId = subnet,
        SecurityGroupIds = [ security_group['GroupId'] ],
        UserData = user_script,
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [{
                'Key': 'Name',
                'Value': name_tag
            }],
        }],
    )

    return cluster

def main():
    KEY_NAME = 'ms_kp_pem'
    GK_SECURITY_GROUP_NAME = 'gk_securityGroup'
    TH_SECURITY_GROUP_NAME = 'th_securityGroup'
    PROXY_SECURITY_GROUP_NAME = 'proxy_securityGroup'
    MYSQL_SECURITY_GROUP_NAME = 'mysql_securityGroup'
    ZONE_NAME = 'us-east-1a'

    gk_ip_permissions = [
        {
            'IpProtocol': 'tcp',
            'FromPort': 80,
            'ToPort': 80,
            'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
        },
        {
            'IpProtocol': 'tcp',
            'FromPort': 22,
            'ToPort': 22,
            'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
        }, 
    ]

    th_ip_permissions = [        
        {
            'IpProtocol': 'tcp',
            'FromPort': 22,
            'ToPort': 22,
            'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
        },       
    ]
    
    vpc_id = ec2_client.describe_vpcs()['Vpcs'][0]['VpcId']
    gk_security_group = create_security_group(name=GK_SECURITY_GROUP_NAME, desc='GateKeeper security group', vpc_id=vpc_id, ip_permissions=gk_ip_permissions)
    proxy_security_group = create_security_group(name=PROXY_SECURITY_GROUP_NAME, desc='Proxy security group', vpc_id=vpc_id, ip_permissions=th_ip_permissions)
    mysql_ecurity_group = create_security_group(name=MYSQL_SECURITY_GROUP_NAME, desc='MySQL security group', vpc_id=vpc_id, ip_permissions=None)
    create_key_pair(KEY_NAME)
    zone_subnet_id = get_subnet_id(ZONE_NAME)  

    user_script_sn = None
    if os.path.exists('mySql_stand_alone.sh'):
        with open('mySql_stand_alone.sh', 'r') as file:
            user_script_sn = file.read() 

    user_script_slave = None
    if os.path.exists('mySql_cluster_slave.sh'):
        with open('mySql_cluster_slave.sh', 'r') as file:
            user_script_slave = file.read()

    user_script_master = None
    if os.path.exists('mySql_cluster_master.sh'):
        with open('mySql_cluster_master.sh', 'r') as file:
            user_script_master = file.read()

    user_script_proxy = None
    if os.path.exists('deploy_proxy_app.sh'):
        with open('deploy_proxy_app.sh', 'r') as file:
            user_script_proxy = file.read()
  
 
    single_node = create_cluster(1, 't2.micro', KEY_NAME, ZONE_NAME, zone_subnet_id, mysql_ecurity_group, user_script_sn, 'stand_alone')    
    # start the single node
    sn_instance_ids =  [instance.id for instance in single_node]
    ec2_client.start_instances(InstanceIds = sn_instance_ids)   

    slaves = create_cluster(3, 't2.large', KEY_NAME, ZONE_NAME, zone_subnet_id, mysql_ecurity_group, user_script_slave, 'slave')
    # start the slaves
    slave_instance_ids =  [instance.id for instance in slaves]
    ec2_client.start_instances(InstanceIds = slave_instance_ids)

    master = create_cluster(1, 't2.large', KEY_NAME, ZONE_NAME, zone_subnet_id, mysql_ecurity_group, user_script_master, 'master')
    # start the master
    master_instance_ids =  [instance.id for instance in master]
    ec2_client.start_instances(InstanceIds = master_instance_ids)  

    proxy = create_cluster(1, 't2.medium', KEY_NAME, ZONE_NAME, zone_subnet_id, proxy_security_group, user_script_proxy, 'proxy')
    # start the proxy
    proxy_instance_ids =  [instance.id for instance in proxy]
    ec2_client.start_instances(InstanceIds = proxy_instance_ids)   

    # wait for all instances to be running before proceeding
    instanceIds = [*sn_instance_ids, *slave_instance_ids, *master_instance_ids, *proxy_instance_ids]
    waiter = ec2_client.get_waiter('instance_running')
    waiter.wait(InstanceIds = instanceIds)

    # reload the instance attributes 
    single_node[0].reload() 
    master[0].reload()
    slaves[0].reload()
    slaves[1].reload()
    slaves[2].reload()  
    proxy[0].reload()    

    sg_mysql = ec2.SecurityGroup(mysql_ecurity_group['GroupId'])
    # add inbound rules to mysql security group
    sg_mysql.authorize_ingress(
        IpPermissions=[
            {                
                'IpProtocol': 'tcp',
                'FromPort': 3306,
                'ToPort': 3306, 
                'UserIdGroupPairs': [{'GroupId': proxy_security_group['GroupId']}],    
            },
            {
                'IpProtocol': 'icmp',
                'FromPort': 8,
                'ToPort': -1,
                'UserIdGroupPairs': [{'GroupId': proxy_security_group['GroupId']}]               
            },
        ]
    )
    
    # TRUSTED HOST
    user_script_trusted_host = None
    if os.path.exists('deploy_thost_app.sh'):
        with open('deploy_thost_app.sh', 'r') as file:
            user_script_trusted_host = file.read()
    
    trusted_host = create_cluster(1, 't2.large', KEY_NAME, ZONE_NAME, zone_subnet_id, proxy_security_group, user_script_trusted_host, 'trusted host')
    # start the trusted host
    trusted_host_instance_ids =  [instance.id for instance in trusted_host]
    ec2_client.start_instances(InstanceIds = trusted_host_instance_ids)  

    # wait for the trusted host to be running before proceeding
    waiter.wait(InstanceIds = trusted_host_instance_ids)  
    
    # reload the instance attributes  
    trusted_host[0].reload()

    # GATEKEEPER
    user_script_gk = None
    if os.path.exists('deploy_gk_app.sh'):
        with open('deploy_gk_app.sh', 'r') as file:
            user_script_gk = file.read() % (trusted_host[0].private_ip_address, proxy[0].private_ip_address, proxy[0].private_ip_address)

    gateKeeper = create_cluster(1, 't2.large', KEY_NAME, ZONE_NAME, zone_subnet_id, gk_security_group, user_script_gk, 'gatekeeper')
    # start the gatekeeper
    gk_instance_ids =  [instance.id for instance in gateKeeper]
    ec2_client.start_instances(InstanceIds = gk_instance_ids)

    # wait for the gateKeeper to be running before proceeding
    waiter.wait(InstanceIds = gk_instance_ids)

    # reload the instance attributes    
    gateKeeper[0].reload()    

    gkCidrIp = f'{gateKeeper[0].private_ip_address}/32'
    sg_proxy = ec2.SecurityGroup(proxy_security_group['GroupId'])
    # add an inbound rule to proxy security group
    sg_proxy.authorize_ingress(IpProtocol="tcp",CidrIp=gkCidrIp,FromPort=80,ToPort=80)    

    # output Dns names
    print(f'{master[0].public_dns_name}:{master[0].private_dns_name}:{master[0].private_ip_address} \
          :{slaves[0].public_dns_name}:{slaves[0].private_dns_name}:{slaves[0].private_ip_address} \
          :{slaves[1].public_dns_name}:{slaves[1].private_dns_name}:{slaves[1].private_ip_address} \
          :{slaves[2].public_dns_name}:{slaves[2].private_dns_name}:{slaves[2].private_ip_address} \
          :{proxy[0].public_dns_name}:{single_node[0].public_dns_name}:{gateKeeper[0].public_dns_name}')

if __name__ == "__main__":
    main()