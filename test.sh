#!/bin/bash
DATACENTER=$1
MASTERVMNAME=$2
echo "datacenter=$1"
echo "masterVmName=$2"
if [ "init" = "$3" ]
  then sudo echo "initializing swarm" && sudo docker swarm init --advertise-addr eth0
  else JOINTOKEN=$(curl $2:8888/manager-token.txt); echo "joining swarm with token $JOINTOKEN" && sudo docker swarm join --token $JOINTOKEN swarmMaster0:2377
fi
