#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
# Adapted by duartegithub

set -o allexport && source .env && set +o allexport

printf "${C_BLUE}\n>>> STOPPING NETWORK\n${C_RESET}"

# Shut down the Docker containers that might be currently running.
docker compose -f docker-compose.yml stop

for file in $(ls expand/ | grep docker-compose); do
  docker compose -f $file stop
done
