# HowTo

Use Powershell

## Create resource group
New-AzureRmResourceGroup -Location <String lacation> -Name <String rgName>

## Deploy infrastructure
New-AzureRmResourceGroupDeployment -Name <String deploymentName> -ResourceGroupName <String rgName> -TemplateFile deploy_infra.json

This will setup following infrastructure
* 1 Public IP with an Azure Load Balancer
* 3 Master node VMs that can be sshed to via 2200, 2201, 2202 respectively and with <publicIP>:80 load balanced across 8080 on the 3 nodes
  * Docker Engine (Swarm Manager)
  * Consul server (Cluster of 3, already bootstrapped) with DNS integration to host and containers
  * Consul registrator
  * Kong Api Gateway
* 1 Worker Node VM scale set with initially 3 Workers
  * Docker Engine (Swarm Worker)
  * Consul agent
  * Consul registrator
* 1 MySql server VM
  * mysql with GMT zone, utf8 listening on 3306

# Docker Swarm services

## Deploy infrastructure services
publish service ports to host directly using --publish mode=host
services will run on the docker host's bridge network and expose ports via port mapping to the host
Example: kong running on 10.0.0.4 node (swarmMaster0), sees interfaces eth0 and localhost
eth0 has 172.17.0.2 and gateway 172.17.0.1
using DNS server 168.63.129.16 (which is the only entry in its resolv.conf)

### postgre (required by kong for now)
```
docker service create --publish mode=host,target=5432,published=5432 --env SERVICE_NAME=postgres --env POSTGRES_USER=kong --env POSTGRES_DB=kong --env POSTGRES_PASSWORD=kong --env SERVICE_5432_CHECK_TCP=true --env SERVICE_5432_CHECK_INTERVAL=15s --env SERVICE_5432_CHECK_TIMEOUT=3s --constraint "node.role == worker" postgres:9.4
```

### redis
```
docker service create --mount type=volume,source=redis-data,target=/data --publish mode=host,target=6379,published=6379 --env SERVICE_NAME=redis --env REDIS_AUTH=notSecureP455w0rd --env SERVICE_6379_CHECK_TCP=true --env SERVICE_6379_CHECK_INTERVAL=15s --env SERVICE_6379_CHECK_TIMEOUT=3s --constraint "node.role == worker" ocbesbn/redis:latest
```

### idpro
on mysql0, execute `create database idpro;` against mysql
```
docker service create --publish mode=host,target=3005,published=3005 --env MYSQL_HOST=$(curl swarmMaster0:8500/v1/catalog/service/mysql | grep -o -e "\"Address\":\"[^,]*" | grep -o "[^\"]*" | grep -v "Address"| grep -v ":") --env MYSQL_PORT=3306 --env SERVICE_NAME=idpro --env APP_HOST=52.233.155.169 --env APP_HOST_PROTOCOL=http --env APP_HOST_PORT=3005 --env GATEWAY_SCHEME=http --env GATEWAY_IP=52.233.155.169 --env GATEWAY_PORT=80 --env GATEWAY_CALLBACK=auth/callback --env CONSUL_HOST=172.17.0.1 --env SERVICE_3005_CHECK_HTTP=/register --env SERVICE_3005_CHECK_INTERVAL=15s --env SERVICE_3005_CHECK_TIMEOUT=3s ocbesbn/idpro:latest
```

### kong
```
docker service create --mode global --publish mode=host,target=8080,published=8080 --publish mode=host,target=8443,published=8443 --publish mode=host,target=8001,published=8001 --env DNS_RESOLVER=172.17.0.1 --env SERVICE_NAME=kong --env KONG_DATABASE=postgres --env REDIS_AUTH=notSecureP455w0rd --env KONG_PG_HOST=postgres.service.consul --env KONG_PG_PORT=5432  --env APP_HOST=idpro.service.consul --env APP_HOST_PROTOCOL=http --env APP_HOST_PORT=3005 --env GATEWAY_SCHEME=http --env GATEWAY_IP=52.233.155.169 --env GATEWAY_PORT=80 --env GATEWAY_CALLBACK=auth/callback --env POSTGRES_USER=kong --env POSTGRES_PASSWORD=kong --env POSTGRES_DB=kong --env LOG_PORT=5000 --env LOG_HOST=172.17.0.1 --env REDIS_HOST=redis.service.consul --env REDIS_PORT=6379 --env SERVICE_8001_CHECK_HTTP=/ --env SERVICE_8001_CHECK_INTERVAL=15s --env SERVICE_8001_CHECK_TIMEOUT=3s --env SERVICE_8001_NAME=kong-api --env SERVICE_8080_NAME=kong --env SERVICE_8443_NAME=kong-https --constraint "node.role == manager" ocbesbn/api-gw:latest
```

### api-registrator
```
docker service create --env SERVICE_NAME=api-registrator --env CONSUL_HOST=consul --env GATEWAY_CALLBACK=auth/callback --env KONG_HOST=kong-api --env KONG_PORT=8001 --env API_REGISTRY_PORT=3004 --publish mode=host,target=3004,published=3004 --constraint "node.role == worker" ocbesbn/api-registrator:latest
```

### ELK

#### ElasticSearch
```
docker service create \
-—publish mode=host,target=9200,published=9200 \
-—publish mode=host,target=9300,published=9300 \
—-env ES_JAVA_OPTS=“-Xmx1g -Xms1g” \
-—env SERVICE_9200_NAME=elastic \
-—env SERVICE_9300_NAME=elastic-TCP \
-—env SERVICE_9200_CHECK_HTTP=/ \
--env SERVICE_9200_CHECK_INTERVAL=15s \
—-env SERVICE_9200_CHECK_TIMEOUT=3s \
-—env SERVICE_9300_CHECK_TCP =/ \
--env SERVICE_9300_CHECK_INTERVAL=15s \
—-env SERVICE_9300_CHECK_TIMEOUT=3s \
-—constraint "node.role == worker" ocbesbn/elasticsearch:latest
```

#### kibana
```
docker service create \
-—publish mode=host,target=5601,published=5601 \
-—env SERVICE_5601_NAME=kibana \
-—env SERVICE_5601_CHECK_HTTP=/ \
—-env SERVICE_5601_CHECK_INTERVAL=15s \
—-env SERVICE_5601_CHECK_TIMEOUT=3s \
—-env ELASTICSEARCH_IP=elastic.service.consul \
-—constraint "node.role == worker" \
ocbesbn/kibana:latest
```

#### logstash
```
docker service create \
-—publish
mode=host,target=5000,published=5000,protocol=udp \
-—publish mode=host,target=12201,published=12201,protocol=udp \
-—env SERVICE_12201_NAME=logstash-gelf \
-—env SERVICE_12201_CHECK_UDP=/ 
--env SERVICE_12201_CHECK_INTERVAL=15s \
—-env SERVICE_12201_CHECK_TIMEOUT=3s \
-—env SERVICE_5000_NAME=logstash-udp \
-—env SERVICE_5000_CHECK_UDP=/ \
--env SERVICE_5000_CHECK_INTERVAL=15s \
—-env SERVICE_5000_CHECK_TIMEOUT=3s \
—-env ELASTICSEARCH_IP=elastic.service.consul \
-—constraint "node.hostname == postgres0" \
ocbesbn/logstash:latest
```

##### ToDo
Add LB for logstash, so docker not necessarily to resolve dynamic IP

#### How to enable logging
While creating docker service enable log option as 
```
docker service create ... --log-driver=gelf --log-opt "gelf-address=udp://logstash-gelf.service.consul:12201"
```
As said logstash url will change as there will be LB for logstash

## Deploy application services
Similar to infrastructure, only out of scope of this document

## Configure Automated Deployments

Assuming that the service has initially been started with `docker service create` on target env.
The depployment can update the existing service and will take into account any update parallelism and deployment settings
configured on the service since creation.
The deployment script will just figure out the service ID based on docker image repository name, then call `docker service update --force` specifying new image to load.
This defaults to a rolling restart of the service and will wait for the deployment to complete before the build goes green.

1. Add project to circle CI
2. Add private key to circleci project SSH permissions
3. edit circle.yml and add a deployment (assuming it has been built to docker image already)
Example
```
  development:
    branch: develop
    commands:
      - docker login -u $DOCKER_USER -p $DOCKER_PASS -e $DOCKER_EMAIL
      - docker tag ocbesbn/api-registrator:latest ocbesbn/api-registrator:dev
      - docker push ocbesbn/api-registrator:dev
      - curl https://raw.githubusercontent.com/gr4per/azureswarm/master/deploy_service.sh > deploy_service.sh
      - chmod +x deploy_service.sh
      - ./deploy_service.sh dm 52.233.155.169 ocbesbn/api-registrator dev
```
