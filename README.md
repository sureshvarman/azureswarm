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

### mysql server
included in deployment template to run on mysql0
//docker service create --publish mode=host,target=3306,published=3306 --env SERVICE_NAME=mysql --env MYSQL_ROOT_PASSWORD=root --constraint "node.id == 7l8nlapahgz7it28555srxehy" mysql
TODO:
add real cluster
add consul agent per mysql node and add healthcheck

## deploy services
publish service ports to host directly using --publish mode=host
services will run on the docker host's bridge network and expose ports via port mapping to the host
Example: kong running on 10.0.0.4 node (swarmMaster0), sees interfaces eth0 and localhost
eth0 has 172.17.0.2 and gateway 172.17.0.1
using DNS server 168.63.129.16 (which is the only entry in its resolv.conf)

### postgre (required by kong for now)
docker service create --publish mode=host,target=5432,published=5432 --env SERVICE_NAME=postgres --env POSTGRES_USER=kong --env POSTGRES_DB=kong --env POSTGRES_PASSWORD=kong --env SERVICE_5432_CHECK_TCP=true --env SERVICE_5432_CHECK_INTERVAL=15s --env SERVICE_5432_CHECK_TIMEOUT=3s --constraint "node.role == worker" postgres:9.4

### redis
docker service create --publish mode=host,target=6379,published=6379 --env SERVICE_NAME=redis --env REDIS_AUTH=notSecureP455w0rd --env SERVICE_6379_CHECK_TCP=true --env SERVICE_6379_CHECK_INTERVAL=15s --env SERVICE_6379_CHECK_TIMEOUT=3s --constraint "node.role == worker" ocbesbn/redis:latest

### kong
PG_HOST=$(curl swarmMaster0:8500/v1/catalog/service/postgres | grep -o -e "\"Address\":\"[^,]*" | grep -o "[^\"]*" | grep -v "Address"| grep -v ":")
PG_PORT=$(curl swarmMaster0:8500/v1/catalog/service/postgres | grep -o "ServicePort\":[^,]*" | cut -d':' -f 2)
RD_HOST=$(curl swarmMaster0:8500/v1/catalog/service/redis | grep -o -e "\"Address\":\"[^,]*" | grep -o "[^\"]*" | grep -v "Address"| grep -v ":")
RD_PORT=$(curl swarmMaster0:8500/v1/catalog/service/redis | grep -o "ServicePort\":[^,]*" | cut -d':' -f 2)
docker service create --mode global --publish mode=host,target=8080,published=8080 --publish mode=host,target=8443,published=8443 --publish mode=host,target=8001,published=8001 --env SERVICE_NAME=kong --env KONG_DATABASE=postgres --env REDIS_AUTH=notSecureP455w0rd --env KONG_PG_HOST=$PG_HOST --env KONG_PG_PORT=$PG_PORT  --env APP_HOST=52.233.155.169 --env APP_HOST_PROTOCOL=http --env APP_HOST_PORT=80 --env GATEWAY_SCHEME=http --env GATEWAY_IP=52.233.155.169 --env GATEWAY_PORT=8080 --env GATEWAY_CALLBACK=auth/callback --env HOST=0.0.0.0 --env POSTGRES_USER=kong --env POSTGRES_PASSWORD=kong --env POSTGRES_DB=kong --env LOG_PORT=5000 --env LOG_HOST=172.17.0.1 --env REDIS_HOST=$RD_HOST --env REDIS_PORT=$RD_PORT --env SERVICE_8001_CHECK_HTTP=/ --env SERVICE_8001_CHECK_INTERVAL=15s --env SERVICE_8001_CHECK_TIMEOUT=3s --constraint "node.role == manager" ocbesbn/api-gw:latest


APP_HOST env variable refer to idpro (external access)
APP_HOST (external IP for gateway)
APP_HOST_PROTOCOL (http for now)
APP_HOST_PORT (80)

GATEWAY_SCHEME (external access to kong)
GATEWAY CALLBACK (idpro callback (from kong to idpro))

HOST - not used 

LOG_HOST/LOG_PORT: used to get nginx and openresty logs to logstash ! TODO

### idpro
