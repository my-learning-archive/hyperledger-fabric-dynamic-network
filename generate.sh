#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# PROCESSING VARIABLES 
##############################################################

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file
SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_CFG_PATH=${SCRIPT}
CHANNEL_NAME=allarewelcome

mkdir -p config
rm -fr config/*
rm -fr crypto-config/*




############################################################## 
# GENERATING CERTIFICATES FOR BASE ORGS 
##############################################################

for ORG in "org1" "org2"; do

  printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR ${ORG}\n${C_RESET}"

  ORG_NAME=${ORG}
  ORG_URL=${ORG_NAME}.${PROJECT_URL}
  FABRIC_CA_CLIENT_DIR=/home/student/.fabric-ca-client
  ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_CFG_PATH}/crypto-config/peerOrganizations/${ORG_URL}
  CA_7054_PORT=$(yq '.services."ca.'${ORG_URL}'".ports' ${FABRIC_CFG_PATH}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')
  
  ADMIN_USERNAME=admin
  ADMIN_PASSWORD=adminpw

  echo y | rm -r ${FABRIC_CA_CLIENT_DIR}

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

  docker compose -f ${FABRIC_CFG_PATH}/docker-compose.yml up -d ca.${ORG_URL}

  sleep 10

  . create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
  createOrg
  createEntity peer1 peer1 peer1pw

done




############################################################## 
# GENERATING CERTIFICATES FOR ORDERERS
##############################################################

printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR THE ORDERER ORG\n${C_RESET}"

ORG_URL=${PROJECT_URL}
FABRIC_CA_CLIENT_DIR=/home/student/.fabric-ca-client
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_CFG_PATH}/crypto-config/ordererOrganizations/${ORG_URL}
CA_7054_PORT=$(yq '.services."ca.'${ORG_URL}'".ports' ${FABRIC_CFG_PATH}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')

ADMIN_USERNAME=admin
ADMIN_PASSWORD=adminpw

echo y | rm -r ${FABRIC_CA_CLIENT_DIR}

mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

docker compose -f ${FABRIC_CFG_PATH}/docker-compose.yml up -d ca.${ORG_URL}

sleep 10

. create-crypto.sh orderer ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
createOrg




############################################################## 
# GENERATING GENESIS BLOCK 
##############################################################

printf "${C_BLUE}\n>>> GENERATING GENESIS BLOCK FOR ORDERER\n${C_RESET}"
configtxgen -profile TwoOrgOrdererGenesis -channelID system-channel -outputBlock ./config/genesis.block
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi




############################################################## 
# GENERATING CHANNEL CREATION TRANSACTION 
##############################################################

printf "${C_BLUE}\n>>> GENERATING CHANNEL CREATION TRANSACTION\n${C_RESET}"
configtxgen -profile TwoOrgChannel -outputCreateChannelTx ./config/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel creation transaction..."
  exit 1
fi




############################################################## 
# GENERATING ANNCHOR PEER TRANSACTIONS 
##############################################################

printf "${C_BLUE}\n>>> GENERATING ANCHOR PEER TRANSACTION FOR org1\n${C_RESET}"
configtxgen -profile TwoOrgChannel -outputAnchorPeersUpdate ./config/Org1MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg Org1MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org1MSP..."
  exit 1
fi

printf "${C_BLUE}\n>>> GENERATING ANCHOR PEER TRANSACTION FOR org2\n${C_RESET}"
configtxgen -profile TwoOrgChannel -outputAnchorPeersUpdate ./config/Org2MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg Org2MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org2MSP..."
  exit 1
fi