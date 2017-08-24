#!/usr/bin/python

import json

myip='127.0.0.1'
fmyip = open('ip.txt', 'r')
temp=fmyip.readline()
myip=temp.strip()
fmyip.close()

print myip

fcluster = open('cluster.cfg', 'r')
clusterCfg = json.load(fcluster)

fhosts = open('hosts.cfg', 'r')
hostsCfg = json.load(fhosts)

hosts={}
flumeHosts=[]
impalaHosts=[]
zookeeperHosts=[]

for host in hostsCfg['items']:
    hosts[host['hostId']] = host["ipAddress"]

for service in clusterCfg['items'][0]['services']:
    if service['type'] == "ZOOKEEPER":
        for role in service['roles']:
            zookeeperHosts.append(hosts[role['hostRef']['hostId']])
            
    if service['type'] == "FLUME":
        for role in service['roles']:
            flumeHosts.append(hosts[role['hostRef']['hostId']])

    if service['type'] == "IMPALA":
        for role in service['roles']:
            if role['type'] == 'IMPALAD':
                impalaHosts.append(hosts[role['hostRef']['hostId']])

print hosts
print zookeeperHosts
print flumeHosts
print impalaHosts

outfile=open('hosts.txt','w')
i=0
for ip in hosts.values():
    outfile.write(ip)
    i=i+1
    if i != len(hosts.values()):
        outfile.write(",")
outfile.close()

outfile=open('zookeepernodes.txt','w')
i=0
for ip in zookeeperHosts:
    outfile.write(ip)
    i=i+1
    if i != len(zookeeperHosts):
        outfile.write(",")
outfile.close()

i=0
outfile=open('flumenodes.txt','w')
for ip in flumeHosts:
    outfile.write(ip)
    i=i+1
    if i != len(flumeHosts):
        outfile.write(",")
outfile.close()

containsMyIP=False
outfile=open('impaladnodes.txt','w')
for ip in impalaHosts:
    if myip==ip:
        containsMyIP=True
        break
        
print "containsMyIP:", containsMyIP

if containsMyIP==True:
    outfile.write("127.0.0.1")
else:
    outfile.write(impalaHosts[0])

outfile.close()
