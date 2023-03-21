#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# STOPPING THE NETWORK 
##############################################################

printf "${C_BLUE}\n>>> STOPPING THE NETWORK\n${C_RESET}"

# Shut down the Docker containers that might be currently running.
docker compose -f docker-compose.yml stop

for file in $(ls expand/ | grep docker-compose); do
  docker compose -f $file stop
done
