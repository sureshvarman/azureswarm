# HowTo

Use Powershell

## Create resource group
New-AzureRmResourceGroup -Location <String lacation> -Name <String rgName>

## Deploy infrastructure
New-AzureRmResourceGroupDeployment -Name <String deploymentName> -ResourceGroupName <String rgName> -TemplateFile deploy_infra.json

## Docker Swarm services

### start consul cluster service on master nodes
(this is part of custom script and will run on vm deployment already)
docker run -d -v /consul:/consul --restart always --env SERVICE_IGNORE=true --net=host gliderlabs/consul-server -server -join swarmMaster0 -join swarmMaster1 -join swarmMaster2 -bootstrap-expect 3 -ui -bind=$ADV_ADDR -data-dir=/consul/data -config-dir=/consul/config

(alternative to run this as swarm service, but we have node ids then instead of node names)
docker service create --hostname="{{.Node.ID}}" --env SERVICE_IGNORE=true --env SERVICE_NAME="consul-server" --mount type=bind,source=/consul/config,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8600,published=8600 --publish mode=host,target=8600,protocol=udp,published=8600 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-server --constraint 'node.role == manager' gliderlabs/consul-server -server -bootstrap-expect 3 -ui -config-dir /configdir -data-dir=/consul/data


### start consul agents on swarm workers
(this is run in worker-install.sh already on vm deployment)
sudo docker run -d -v /consul:/consul --name consul-agent --restart always --env SERVICE_IGNORE=true --net=host gliderlabs/consul-server -join ${HOSTPREFIX}0 -join ${HOSTPREFIX}1 -join ${HOSTPREFIX}2 -ui -bind=$ADV_ADDR -data-dir=/consul/data -config-dir=/consul/config
 
// alternative: run consul agent as service on all nodes except consul server nodes
#sudo docker service create --env SERVICE_NAME="consul-agent" --env SERVICE_8500_CHECK_INTERVAL="15s" --env SERVICE_8500_CHECK_TIMEOUT="3s" --env SERVICE_8500_CHECK_HTTP="/v1/catalog/services" --mount type=bind,source=/consul,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-agent --constraint 'engine.labels.nodetype != consul' gliderlabs/consul-server -ui -join consulServer0 -config-dir /configdir
// alternative2: trying to align hostname with registrator
sudo docker service create --hostname="{{.Node.ID}}" --env SERVICE_NAME="consul-agent" --env SERVICE_8500_CHECK_INTERVAL="15s" --env SERVICE_8500_CHECK_TIMEOUT="3s" --env SERVICE_8500_CHECK_HTTP="/v1/catalog/services" --mount type=bind,source=/consul,destination=/configdir --publish mode=host,target=8500,published=8500 --publish mode=host,target=8300,published=8300 --publish mode=host,target=8301,published=8301 --publish mode=host,target=8301,protocol=udp,published=8301 --publish mode=host,target=8302,published=8302 --publish mode=host,target=8302,protocol=udp,published=8302 --mode global --name consul-agent --constraint 'engine.labels.nodetype != consul' gliderlabs/consul-server -ui -join consulServer0 -config-dir /configdir


### start consul registrator on all swarm nodes
(this is done in master-install.sh and worker-install.sh)
sudo docker run -d --net=host --volume=/var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://localhost:8500

//alternative: run registrator as service
sudo docker service create --hostname="{{.Node.ID}}" --mount type=bind,source=/consul,destination=/consul --mount type=bind,source=/var/run/docker.sock,destination=/tmp/docker.sock --mode global --name consul-registrator gr4per/registrator -cleanup -ttl=60 -ttl-refresh=50

## deploy services
publish service ports to host directly using --publish mode=host

docker service create --publish mode=host,target=3306,published=3306 --env SERVICE_NAME=mysql --env MYSQL_ROOT_PASSWORD=root --constraint "node.id == 7l8nlapahgz7it28555srxehy" mysql
