#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# TEARING DOWN NETWORK 
##############################################################

printf "${C_BLUE_BOLD}\nteardown.sh:${C_BLUE}\n > TEARING DOWN NETWORK\n\n${C_RESET}"

docker compose -f docker-compose.yml kill && docker compose -f docker-compose.yml down --volumes --remove-orphans

CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
if [ -z "${CONTAINER_IDS}" -o "${CONTAINER_IDS}" == " " ]; then
    echo "No containers available for deletion."
else
    docker rm -f ${CONTAINER_IDS}
fi

DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
if [ -z "${DOCKER_IMAGE_IDS}" -o "${DOCKER_IMAGE_IDS}" == " " ]; then
    echo "No images available for deletion."
else
    docker rmi -f ${DOCKER_IMAGE_IDS}
fi

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
rm -rvf ${SCRIPT}/expand/
rm -rvf ${SCRIPT}/crypto-config/
rm -rvf ${SCRIPT}/config/
rm -rvf ${SCRIPT}/*_tmp/
