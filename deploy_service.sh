#!/bin/sh
echo "usage $1 = username, $2 = target env public address, $3 = image repository, $4 = image tag"
DS='$(docker service ls | grep "'
#$echo "command = $DS"
DS=$DS$3'" | grep -o "\S*" | grep -m 1 ".*")'
#echo "command = $DS"
echo "docker service update --force --image $3:$4 $DS" | ssh $1@$2 -p 2200 
#ssh $1@$2 -p 2200 < run_in_ssh.txt
