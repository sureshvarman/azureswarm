#!/bin/bash
DATACENTER=$1
MASTERVMNAME=$2
ADMINUSER=$3
echo "datacenter=$1"
echo "masterVmName=$2"
echo "adminUserName=$3"
echo "updating apt" && sudo apt-get update
echo "loading key from p80.pool.sks-keyservers.net"
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "adding repo" && sudo apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
echo "updating apt again" && sudo apt-get update
echo "updating cache policy" && apt-cache policy docker-engine
echo "installing docker" && sudo apt-get install -y docker-engine
echo "adding user to docker group" && sudo usermod -aG docker $3
sudo echo '{  "labels": ["nodetype=worker"]}' > daemon.json
sudo mv daemon.json /etc/docker/
sudo systemctl restart docker
JOINTOKEN=$(curl $2:8888/worker-token.txt)
echo "joining swarm with token $JOINTOKEN" && sudo docker swarm join --token $JOINTOKEN $2:2377
sudo echo "swarm worker init finished"
sudo echo "adding consul agent config"
ADV_ADDR=$(ifconfig | grep -A1 "eth0" | grep -o "inet addr:\S*" | grep -o -e "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
DOCKER_HOST=$(hostname)
DEN=$(sudo docker info | grep "Name:" | grep -o "\S*" | grep -v "Name:")
sudo echo "advertise_address=$ADV_ADDR, hostname=$DOCKER_HOST, docker engine name=$DEN"
sudo mkdir /consul
sudo mkdir /consul/config
sudo mkdir /consul/data
sudo echo "{\"datacenter\": \"$DATACENTER\",\"advertise_addr\": \"$ADV_ADDR\"}" > /consul/config/agent-config.json
HOSTPREFIX=${MASTERVMNAME%?}
sudo docker run -d -v /consul:/consul --name consul-agent --restart always --env SERVICE_IGNORE=true --net=host gliderlabs/consul-server -join ${HOSTPREFIX}0 -join ${HOSTPREFIX}1 -join ${HOSTPREFIX}2 -ui -bind=$ADV_ADDR -data-dir=/consul/data -config-dir=/consul/config
sudo echo "starting consul registrator"
sudo docker run -d --net=host --restart always --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://localhost:8500
sudo echo "consul setup finished"
