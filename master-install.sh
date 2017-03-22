#!/bin/bash
DATACENTER=$1
MASTERVMNAME=$2
ADMINUSER=$3
echo "datacenter=$1"
echo "masterVmName=$2"
echo "adminUserName=$3"

#install docker
echo "updating apt" && sudo apt-get update
echo "loading key from p80.pool.sks-keyservers.net"
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "adding repo" && sudo apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
echo "updating apt again" && sudo apt-get update
echo "updating cache policy" && apt-cache policy docker-engine
echo "installing docker" && sudo apt-get install -y docker-engine
echo "adding user to docker group" && sudo usermod -aG docker $3
sudo echo "setting nodeType in /etc/docker/daemon.json" && echo '{  "labels": ["nodetype=master"]}' > daemon.json
sudo mv daemon.json /etc/docker/
sudo echo "restarting docker" && systemctl restart docker

#init / join swarm cluster
if [ "init" = "$4" ]
  then sudo echo "initializing swarm" && sudo docker swarm init --advertise-addr eth0
  else JOINTOKEN=$(curl $2:8888/manager-token.txt); echo "joining swarm with token $JOINTOKEN" && sudo docker swarm join --token $JOINTOKEN $2:2377
fi
sudo echo "configuring swarm token publish via rc.local"
sudo systemctl enable rc-local.service
sudo echo '#!/bin/bash
mkdir /swarmtokenshare
sudo docker swarm join-token worker | grep -o "SWMTKN\S*" > /swarmtokenshare/worker-token.txt
sudo docker swarm join-token manager | grep -o "SWMTKN\S*" >> /swarmtokenshare/manager-token.txt
cd /swarmtokenshare
python -m SimpleHTTPServer 8888' > publish_token.sh
sudo chmod +x publish_token.sh
sudo cp publish_token.sh /etc/rc.local
sudo echo "publishing swarm token"
sudo bash publish_token.sh &
sudo echo "swarm master init finished"

#setup consul
sudo echo "starting consul server..."
sudo echo "adding consul agent config"
ADV_ADDR=$(ifconfig | grep -A1 "eth0" | grep -o "inet addr:\S*" | grep -o -e "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
BRIDGE_IP=$(ifconfig | grep -A1 "docker0" | grep -o "inet addr:\S*" | grep -o -e "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
DOCKER_HOST=$(hostname)
DEN=$(sudo docker info | grep "Name:" | grep -o "\S*" | grep -v "Name:")
sudo echo "advertise_address=$ADV_ADDR, hostname=$DOCKER_HOST, docker engine name=$DEN"
sudo mkdir /consul
sudo mkdir /consul/config
sudo mkdir /consul/data
sudo echo "{\"datacenter\": \"$DATACENTER\",\"advertise_addr\": \"$ADV_ADDR\"}" > /consul/config/agent-config.json
HOSTPREFIX=${MASTERVMNAME%?}
#sudo docker run -d -v /consul:/consul --restart always --env SERVICE_IGNORE=true --net=host gliderlabs/consul-server -server -join ${HOSTPREFIX}0 -join ${HOSTPREFIX}1 -join ${HOSTPREFIX}2 -bootstrap-expect 3 -ui -bind=$ADV_ADDR -data-dir=/consul/data -config-dir=/consul/config
#sudo docker run -d -v /consul:/consul --restart always --env SERVICE_IGNORE=true --net=host consul -server -join ${HOSTPREFIX}0 -join ${HOSTPREFIX}1 -join ${HOSTPREFIX}2 -bootstrap-expect 3 -ui -bind=$ADV_ADDR -data-dir=/consul/data -config-dir=/consul/config -dns-port=53
sudo docker run -d -v /consul/data:/consul/data -v /consul/config:/consul/config --restart always --env SERVICE_IGNORE=true -p 8300:8300 -p 8301:8301 -p 8301:8301/udp -p 8302:8302 -p 8302:8302/udp -p 8400:8400 -p 8500:8500 -p 53:8600/udp consul agent -server -join ${HOSTPREFIX}0 -join ${HOSTPREFIX}1 -join ${HOSTPREFIX}2 -bootstrap-expect 3 -ui -data-dir=/consul/data -config-dir=/consul/config -client 0.0.0.0 -node $DOCKER_HOST
sudo echo "starting consul registrator"
sudo docker run -d --net=host --restart always --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator -ip $ADV_ADDR consul://localhost:8500
sudo echo "configuring name resolution to include consul"
sudo echo "nameserver $ADV_ADDR" > /etc/resolvconf/resolv.conf.d/head
sudo bash -c "echo \"nameserver $BRIDGE_IP\" > /etc/resolvconf/resolv.conf.d/head"
sudo bash -c "echo \"search service.consul\" > /etc/resolvconf/resolv.conf.d/base"
sudo resolvconf -u
sudo echo "consul setup finished"