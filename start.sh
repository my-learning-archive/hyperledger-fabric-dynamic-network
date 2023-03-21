#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# PROCESSING VARIABLES 
##############################################################

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file
CHANNEL_NAME=allarewelcome
CLI_CONTAINER=cli
ORDERER_CONTAINER_HOSTNAME_PORT=orderer0.${PROJECT_URL}:7050
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations




############################################################## 
# STARTING BASE CONTAINERS
##############################################################

printf "${C_BLUE}\n>>> STARTING org1 AND org2 CONTAINERS\n${C_RESET}"
docker compose -f docker-compose.yml up -d ca.${PROJECT_URL} orderer0.${PROJECT_URL} orderer1.${PROJECT_URL} orderer2.${PROJECT_URL} \
    couchdbOrg1Peer0 peer0.org1.${PROJECT_URL} couchdbOrg1Peer1 peer1.org1.${PROJECT_URL} ca.org1.${PROJECT_URL} \
    couchdbOrg2Peer0 peer0.org2.${PROJECT_URL} couchdbOrg2Peer1 peer1.org2.${PROJECT_URL} ca.org2.${PROJECT_URL} \
    cli

sleep 15




############################################################## 
# CREATING THE APPLICATION CHANNEL 
##############################################################

printf "${C_BLUE}\n>>> CREATING APPLICATION CHANNEL - ${CHANNEL_NAME}\n${C_RESET}"
ORDERER_TLS_CA=`docker exec cli  env | grep ORDERER_TLS_CA | cut -d'=' -f2`
docker exec cli peer channel create -o ${ORDERER_CONTAINER_HOSTNAME_PORT} -c $CHANNEL_NAME -f /etc/hyperledger/configtx/$CHANNEL_NAME.tx --tls --cafile $ORDERER_TLS_CA




############################################################## 
# ADDING BASE PEERS TO APPLICATION CHANNEL 
##############################################################

printf "${C_BLUE}\n>>> ADDING peer0.org1 TO ${CHANNEL_NAME}\n${C_RESET}"
docker exec cli peer channel join -b $CHANNEL_NAME.block

printf "${C_BLUE}\n>>> ADDING peer1.org1 TO ${CHANNEL_NAME}\n${C_RESET}"
docker exec -e CORE_PEER_ADDRESS=peer1.org1.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer1.org1.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer1.org1.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer1.org1.${PROJECT_URL}/tls/ca.crt \
    cli peer channel fetch oldest $CHANNEL_NAME.block -c $CHANNEL_NAME --orderer ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile $ORDERER_TLS_CA

docker exec -e CORE_PEER_ADDRESS=peer1.org1.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer1.org1.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer1.org1.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer1.org1.${PROJECT_URL}/tls/ca.crt \
    cli peer channel join -b $CHANNEL_NAME.block

printf "${C_BLUE}\n>>> ADDING peer0.org2 TO ${CHANNEL_NAME}\n${C_RESET}"
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP -e CORE_PEER_ADDRESS=peer0.org2.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/users/Admin@org2.${PROJECT_URL}/msp \
    -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    cli peer channel fetch oldest $CHANNEL_NAME.block -c $CHANNEL_NAME --orderer ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile $ORDERER_TLS_CA

docker exec -e CORE_PEER_LOCALMSPID=Org2MSP -e CORE_PEER_ADDRESS=peer0.org2.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/users/Admin@org2.${PROJECT_URL}/msp \
    -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    cli peer channel join -b $CHANNEL_NAME.block

printf "${C_BLUE}\n>>> ADDING peer1.org2 TO ${CHANNEL_NAME}\n${C_RESET}"
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP -e CORE_PEER_ADDRESS=peer1.org2.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer1.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer1.org2.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer1.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/users/Admin@org2.${PROJECT_URL}/msp \
    -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    cli peer channel fetch oldest $CHANNEL_NAME.block -c $CHANNEL_NAME --orderer ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile $ORDERER_TLS_CA

docker exec -e CORE_PEER_LOCALMSPID=Org2MSP -e CORE_PEER_ADDRESS=peer1.org2.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer1.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer1.org2.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer1.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/users/Admin@org2.${PROJECT_URL}/msp \
    -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    cli peer channel join -b $CHANNEL_NAME.block




############################################################## 
# UPDATING BASE ANCHOR PEERS
##############################################################

printf "${C_BLUE}\n>>> UPDATING org1 ANCHOR PEER\n${C_RESET}"
docker exec -e CORE_PEER_ADDRESS=peer0.org1.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer0.org1.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer0.org1.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org1.${PROJECT_URL}/peers/peer0.org1.${PROJECT_URL}/tls/ca.crt \
    cli peer channel update -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile $ORDERER_TLS_CA -c $CHANNEL_NAME -f /etc/hyperledger/configtx/Org1MSPanchors.tx 
    
printf "${C_BLUE}\n>>> UPDATING org2 ANCHOR PEER\n${C_RESET}"
docker exec -e CORE_PEER_LOCALMSPID=Org2MSP -e CORE_PEER_ADDRESS=peer0.org2.${PROJECT_URL}:7051 \
    -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/peers/peer0.org2.${PROJECT_URL}/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/org2.${PROJECT_URL}/users/Admin@org2.${PROJECT_URL}/msp \
    cli peer channel update -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile $ORDERER_TLS_CA -c $CHANNEL_NAME -f /etc/hyperledger/configtx/Org2MSPanchors.tx 