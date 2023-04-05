#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# PROCESSING VARIABLES 
##############################################################

# In the .env file
PROJECT_URL=${ENV_PROJECT_URL}
CHANNEL_NAME=${ENV_BASE_CHANNEL_NAME} 
SYS_CHANNEL_NAME=${ENV_SYS_CHANNEL_NAME}

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}

TLS_CA_REMOTE_TLS_TARGET=${FABRIC_TARGET}/crypto-config/tlsOrganizations/${PROJECT_URL}/tlsca




############################################################## 
# PROCESSING DIRECTORIES 
##############################################################

echo y | rm -fr ${FABRIC_TARGET}/config/* &> /dev/null
echo y | rm -fr ${FABRIC_TARGET}/crypto-config/* &> /dev/null

mkdir -p ${FABRIC_TARGET}/config
mkdir -p ${TLS_CA_REMOTE_TLS_TARGET}




############################################################## 
# GENERATING CERTIFICATES FOR BASE ORGS 
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > STARTING TLS CA\n\n${C_RESET}"

for ORG_NAME in "org1" "org2"; do

  printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING CRYPTO-MATERIALS - ${ORG_NAME}\n\n${C_RESET}"

  ORG_URL=${ORG_NAME}.${PROJECT_URL}
  ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}
  
  ORG_CA_7054_PORT=$(yq '.services."ca.'${ORG_URL}'".ports' ${FABRIC_TARGET}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')
  ORG_CA_ADMIN_USERNAME=admin
  ORG_CA_ADMIN_PASSWORD=adminpw

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

  docker compose -f ${FABRIC_TARGET}/docker-compose.yml up -d ca.${ORG_URL} tls.ca.${PROJECT_URL}

  sleep 10

  . create-crypto.sh ${ORG_NAME} ${ORG_CA_7054_PORT} ${ORG_CA_ADMIN_USERNAME} ${ORG_CA_ADMIN_PASSWORD}
  createOrg
  createUser "client" "User1" "${ORG_NAME}user1" "${ORG_NAME}user1pw"
  createUserTLS "client" "User1" "${ORG_NAME}user1" "${ORG_NAME}user1pw"
  createEntity "peer0" "${ORG_NAME}peer0" "${ORG_NAME}peer0pw"
  createEntityTLS "peer0" "${ORG_NAME}peer0" "${ORG_NAME}peer0pw"
  createEntity "peer1" "peer1" "${ORG_NAME}peer1pw"
  createEntityTLS "peer1" "${ORG_NAME}peer1" "${ORG_NAME}peer1pw"

done




############################################################## 
# GENERATING CERTIFICATES FOR ORDERERS
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING CRYPTO-MATERIALS - orderers\n\n${C_RESET}"

ORG_URL=${PROJECT_URL}
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/ordererOrganizations/${ORG_URL}

ORG_CA_7054_PORT=$(yq '.services."ca.'${ORG_URL}'".ports' ${FABRIC_TARGET}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')
ORG_CA_ADMIN_USERNAME=admin
ORG_CA_ADMIN_PASSWORD=adminpw

mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

docker compose -f ${FABRIC_TARGET}/docker-compose.yml up -d ca.${ORG_URL}

sleep 10

. create-crypto.sh orderer ${ORG_CA_7054_PORT} ${ORG_CA_ADMIN_USERNAME} ${ORG_CA_ADMIN_PASSWORD}
createOrg
createEntity "orderer0" "orderer0" "orderer0pw"
createEntityTLS "orderer0" "orderer0" "orderer0pw"
createEntity "orderer1" "orderer1" "orderer1pw"
createEntityTLS "orderer1" "orderer1" "orderer1pw"
createEntity "orderer2" "orderer2" "orderer2pw"
createEntityTLS "orderer2" "orderer2" "orderer2pw"




############################################################## 
# GENERATING GENESIS BLOCK 
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING GENESIS BLOCK\n\n${C_RESET}"

configtxgen -configPath ${FABRIC_TARGET} -profile TwoOrgOrdererGenesis -channelID ${SYS_CHANNEL_NAME} -outputBlock ${FABRIC_TARGET}/config/genesis.block




############################################################## 
# GENERATING BASE APPLICATION CHANNEL CREATION TRANSACTION 
##############################################################

printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING APPLICATION CHANNEL CREATION TRANSACTION - ${CHANNEL_NAME}\n\n${C_RESET}"

configtxgen -configPath ${FABRIC_TARGET} -profile TwoOrgChannel -outputCreateChannelTx ${FABRIC_TARGET}/config/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}




############################################################## 
# GENERATING BASE ANCHOR PEER TRANSACTIONS 
##############################################################

for ORG_NAME in "org1" "org2"; do

  printf "${C_BLUE_BOLD}\ngenerate.sh:${C_BLUE}\n > GENERATING ANCHOR PEER UPDATE TRANSACTION - ${ORG_NAME}\n\n${C_RESET}"

  configtxgen -profile TwoOrgChannel -outputAnchorPeersUpdate ${FABRIC_TARGET}/config/${ORG_NAME^}MSPanchors.tx -channelID ${CHANNEL_NAME} -asOrg ${ORG_NAME^}MSP  

done