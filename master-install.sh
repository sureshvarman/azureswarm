#!bin/bash
if $1 = init 
  echo "init for swarm"
fi;
echo "updating apt" && sudo apt-get update
echo "loading key from p80.pool.sks-keyservers.net"
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "adding repo" && sudo apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
echo "updating apt again" && sudo apt-get update
echo "updating cache policy" && apt-cache policy docker-engine
echo "installing docker" && sudo apt-get install -y docker-engine
echo "adding user to docker group" && sudo usermod -aG docker dm
sudo echo "setting nodeType in /etc/docker/daemon.json" && echo '{  "labels": ["nodetype=master"]}' > daemon.json
sudo mv daemon.json /etc/docker/
sudo echo "restarting docker" && systemctl restart docker
if [ "init" = "$1" ]
  then sudo echo "initializing swarm" && sudo docker swarm init --advertise-addr eth0
  else echo "joining swarm" && sudo docker swarm join --token $(nc swarmMaster0 8888 | tail -n1) swarmMaster0:2377
fi

sudo echo "adding consul agent config"
ADV_ADDR=$(ifconfig | grep -A1 "eth0" | grep -o "inet addr:\S*" | grep -o -e "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
DOCKER_HOST=$(hostname)
DEN=$(sudo docker info | grep "Name:" | grep -o "\S*" | grep -v "Name:")
sudo echo "advertise_address=$ADV_ADDR, hostname=$DOCKER_HOST, docker engine name=$DEN"
sudo mkdir /consul
sudo mkdir /consul/config
sudo mkdir /consul/data
#sudo echo "{\"node_name\": \"$DOCKER_HOST\",\"advertise_addr\": \"$ADV_ADDR\"}" > /consul/agent-config.json
sudo echo "{\"advertise_addr\": \"$ADV_ADDR\"}" > /consul/config/agent-config.json
sudo echo "configuring netcat swarm token publish via rc.local"
sudo systemctl enable rc-local.service
sudo echo '#!/bin/bash
while true ; do sudo docker swarm join-token worker | grep -o "SWMTKN\S*" > tokens.txt; sudo docker swarm join-token manager | grep -o "SWMTKN\S*" >> tokens.txt; cat tokens.txt | nc -l -p 8888; done' > publish_token.sh
sudo chmod +x publish_token.sh
sudo cp publish_token.sh /etc/rc.local
sudo echo "publishing swarm token"
sudo bash publish_token.sh &
sudo echo "swarm master init finished"
