# HowTo

Use Powershell

## Create resource group
New-AzureRmResourceGroup -Location <String lacation> -Name <String rgName>

## Deploy infrastructure
New-AzureRmResourceGroupDeployment -Name <String deploymentName> -ResourceGroupName <String rgName> -TemplateFile deploy_infra.json

## Docker Swarm services

### start consul cluster service on master nodes
// run consul server
docker run -d -v /consul:/consul --restart always --env SERVICE_IGNORE=true --net=host gliderlabs/consul-server -server -join swarmMaster0 -join swarmMaster1 -join swarmMaster2 -bootstrap-expect 3 -ui -bind=$ADV_ADDR -data-dir=/consul/data -config-dir=/consul/config

docker service create --hostname="{{.Node.ID}}" --env SERVICE_NAME="consul-server" --mount type=bind,source=/consul/config,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8600,published=8600 --publish mode=host,target=8600,protocol=udp,published=8600 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-server --constraint 'node.role == manager' gliderlabs/consul-server -server -bootstrap-expect 3 -ui -config-dir /configdir -data-dir=/consul/data
--env SERVICE_8500_CHECK_INTERVAL="15s" --env SERVICE_8500_CHECK_TIMEOUT="3s" --env SERVICE_8500_CHECK_HTTP="/v1/catalog/services" 

swarmMaster0: 10.0.0.4 /
swarmMaster1: 10.0.0.6 / 172.17.0.2


### start consul agents on swarm workers

sudo docker run -d --net=host gliderlabs/consul-server -ui -join consulServer0 -bind=$(ifconfig | grep -A1 "eth0" | grep -o "inet addr:\S*" | grep -o -e "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
 
// run consul agent as service on single node
sudo docker service create --mount type=bind,source=/consul,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-agent --constraint 'engine.labels.nodetype != consul' --constraint 'node.id == 8p67052puy43y1p7hxrocys71' gliderlabs/consul-server -ui -join consulServer0 -config-dir /configdir

// run consul agent as service on all nodes except consul server nodes
#sudo docker service create --env SERVICE_NAME="consul-agent" --env SERVICE_8500_CHECK_INTERVAL="15s" --env SERVICE_8500_CHECK_TIMEOUT="3s" --env SERVICE_8500_CHECK_HTTP="/v1/catalog/services" --mount type=bind,source=/consul,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-agent --constraint 'engine.labels.nodetype != consul' gliderlabs/consul-server -ui -join consulServer0 -config-dir /configdir

// trying to align hostname with registrator
sudo docker service create --hostname="{{.Node.ID}}" --env SERVICE_NAME="consul-agent" --env SERVICE_8500_CHECK_INTERVAL="15s" --env SERVICE_8500_CHECK_TIMEOUT="3s" --env SERVICE_8500_CHECK_HTTP="/v1/catalog/services" --mount type=bind,source=/consul,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-agent --constraint 'engine.labels.nodetype != consul' gliderlabs/consul-server -ui -join consulServer0 -config-dir /configdir

--hostname="{{.Node.ID}}"

// run consul agent
sudo docker run -v /consul:/configdir -p 8300:8300 -p 8500:8500 -p 8301:8301 -p 8301:8301/udp -p 8302:8302 -p 8302:8302/udp -d gliderlabs/consul-server -ui -join consulServer0 -config-dir /configdir

### start consul registrator on all swarm nodes

sudo docker run -d --net=host --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://localhost:8500
sudo docker service create --hostname="{{.Node.ID}}" --mount type=bind,source=/consul,destination=/consul --mount type=bind,source=/var/run/docker.sock,destination=/tmp/docker.sock --mode global --name consul-registrator gr4per/registrator -cleanup -ttl=60 -ttl-refresh=50

sudo docker service create --hostname="{{.Node.Description.Hostname}}" --mount type=bind,source=/consul,destination=/consul --mount type=bind,source=/var/run/docker.sock,destination=/tmp/docker.sock --mode global --name consul-registrator gr4per/registrator -cleanup -ttl=60 -ttl-refresh=50

// registration zombies
-> add service list for node and deregistration to custom registrator image start
