#!/bin/bash
echo "usage $1 = username, $2 = target env public address, $3 = image repository, $4 = image tag"
DS='$(docker service ls | grep "'
#$echo "command = $DS"
DS=$DS$3'" | grep -o "\S*" | grep -m 1 ".*")'
#echo "command = $DS"
DS2='SERVICE_ID=$(docker service update --force --image '
DS2="$DS2$3:$4 $DS)"
DS2+='
echo "triggered update of service with id $SERVICE_ID"
monitor() {
for attempt in {1..30}; do
  srvStatus=$(docker inspect $SERVICE_ID | jq --raw-output --exit-status .[0].UpdateStatus.State) 
  if [ $srvStatus = "updating" ]; then
            echo "Waiting for deployment to complete: $srvStatus"
            sleep 5
        else
            echo "Deployment done: $srvStatus"
            return 0
        fi
done
  echo "Service update took too long."
  return 1
}
monitor
'
echo "$DS2" | ssh $1@$2 -p 2200 
echo "$DS2" > run_in_ssh.txt
