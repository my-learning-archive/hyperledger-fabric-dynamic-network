#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# STOPPING NETWORK 
##############################################################

printf "${C_BLUE_BOLD}\nstop.sh:${C_BLUE}\n > STOPPING NETWORK\n\n${C_RESET}"

docker compose -f docker-compose.yml stop

for DOCKER_COMPOSE_FILE in $(ls expand/ | grep docker-compose); do
  docker compose -f ${DOCKER_COMPOSE_FILE} stop
done
