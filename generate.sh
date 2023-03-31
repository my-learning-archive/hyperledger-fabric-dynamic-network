#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# PROCESSING VARIABLES 
##############################################################

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file
CHANNEL_NAME=${BASE_CHANNEL_NAME} # In the .env file
SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}

rm -fr ${FABRIC_TARGET}/config/*
rm -fr ${FABRIC_TARGET}/crypto-config/*
mkdir -p ${FABRIC_TARGET}/config




############################################################## 
# GENERATING CERTIFICATES FOR BASE ORGS 
##############################################################

for ORG_NAME in "org1" "org2"; do

  printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING CRYPTO-MATERIALS FOR ${ORG_NAME}\n\n${C_RESET}"

  ORG_URL=${ORG_NAME}.${PROJECT_URL}
  ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}
  CA_7054_PORT=$(yq '.services."ca.'${ORG_URL}'".ports' ${FABRIC_TARGET}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')
  
  ADMIN_USERNAME=admin
  ADMIN_PASSWORD=adminpw

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

  docker compose -f ${FABRIC_TARGET}/docker-compose.yml up -d ca.${ORG_URL}

  sleep 10

  . create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
  createOrg
  createUser "client" "User1" "user1" "user1pw"
  createEntity "peer0" "peer0" "peer0pw"
  createEntity "peer1" "peer1" "peer1pw"

done




############################################################## 
# GENERATING CERTIFICATES FOR ORDERERS
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING CRYPTO-MATERIALS FOR THE ORDERERS\n\n${C_RESET}"

ORG_URL=${PROJECT_URL}
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/ordererOrganizations/${ORG_URL}
CA_7054_PORT=$(yq '.services."ca.'${ORG_URL}'".ports' ${FABRIC_TARGET}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')

ADMIN_USERNAME=admin
ADMIN_PASSWORD=adminpw

mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

docker compose -f ${FABRIC_TARGET}/docker-compose.yml up -d ca.${ORG_URL}

sleep 10

. create-crypto.sh orderer ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
createOrg
createEntity "orderer0" "orderer0" "orderer0pw"
createEntity "orderer1" "orderer1" "orderer1pw"
createEntity "orderer2" "orderer2" "orderer2pw"




############################################################## 
# GENERATING GENESIS BLOCK 
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING GENESIS BLOCK\n\n${C_RESET}"

configtxgen -configPath ${FABRIC_TARGET} -profile TwoOrgOrdererGenesis -channelID system-channel -outputBlock ${FABRIC_TARGET}/config/genesis.block




############################################################## 
# GENERATING CHANNEL CREATION TRANSACTION 
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING APPLICATION CHANNEL CREATION TRANSACTION FOR ${CHANNEL_NAME}\n\n${C_RESET}"

configtxgen -configPath ${FABRIC_TARGET} -profile TwoOrgChannel -outputCreateChannelTx ${FABRIC_TARGET}/config/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}




############################################################## 
# GENERATING ANCHOR PEER TRANSACTIONS 
##############################################################

for ORG_NAME in "org1" "org2"; do

  printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING ANCHOR PEER UPDATE TRANSACTION FOR ${ORG_NAME}\n\n${C_RESET}"

  configtxgen -profile TwoOrgChannel -outputAnchorPeersUpdate ${FABRIC_TARGET}/config/${ORG_NAME^}MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg ${ORG_NAME^}MSP  

done