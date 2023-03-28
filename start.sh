#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# PROCESSING VARIABLES 
##############################################################

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file
CHANNEL_NAME=${BASE_CHANNEL_NAME} # In the .env file
CLI_CONTAINER=cli
ORDERER_CONTAINER_HOSTNAME_PORT=orderer0.${PROJECT_URL}:7050
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations




############################################################## 
# STARTING BASE CONTAINERS
##############################################################

printf "${C_BLUE}\n>>> STARTING BASE CONTAINERS\n${C_RESET}"

docker compose -f docker-compose.yml up -d \
	ca.${PROJECT_URL} \
	orderer0.${PROJECT_URL} \
	orderer1.${PROJECT_URL} \
	orderer2.${PROJECT_URL} \
	ca.org1.${PROJECT_URL} \
	couchdbOrg1Peer0 peer0.org1.${PROJECT_URL} \
	couchdbOrg1Peer1 peer1.org1.${PROJECT_URL} \
	ca.org2.${PROJECT_URL} \
	couchdbOrg2Peer0 peer0.org2.${PROJECT_URL} \
	couchdbOrg2Peer1 peer1.org2.${PROJECT_URL} \
	cli

sleep 15




############################################################## 
# CREATING THE APPLICATION CHANNEL 
##############################################################

printf "${C_BLUE}\n>>> CREATING APPLICATION CHANNEL - ${CHANNEL_NAME}\n${C_RESET}"

ORDERER_TLS_CA=$(docker exec ${CLI_CONTAINER} printenv ORDERER_TLS_CA)
ORG_NAME="org1"
ORG_URL=${ORG_NAME}.${PROJECT_URL}

docker exec -e CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP \
	-e CORE_PEER_ADDRESS=peer0.${ORG_URL}:7051 \
	-e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.crt \
	-e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.key \
	-e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/ca.crt \
	-e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/Admin@${ORG_URL}/msp \
	-e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/ca.crt \
	-e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.crt \
	-e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.key \
	cli peer channel create -o ${ORDERER_CONTAINER_HOSTNAME_PORT} -c ${CHANNEL_NAME} -f /etc/hyperledger/configtx/${CHANNEL_NAME}.tx --tls --cafile ${ORDERER_TLS_CA}




############################################################## 
# JOINING BASE PEERS TO APPLICATION CHANNEL 
##############################################################

for ORG_NAME in "org1" "org2"; do

	ORG_URL=${ORG_NAME}.${PROJECT_URL}
	PEERS_LIST=$(docker ps --format {{.Names}} | grep ^peer | grep ${ORG_NAME} | sort | tr "." " " | awk '{print $1}')

	for PEER_NAME in ${PEERS_LIST}; do

		printf "${C_BLUE}\n>>> JOINING ${PEER_NAME}.${ORG_NAME} TO ${CHANNEL_NAME}\n${C_RESET}"

		docker exec -e CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP \
			-e CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_URL}:7051 \
			-e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt \
			-e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key \
			-e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt \
			-e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/Admin@${ORG_URL}/msp \
			-e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt \
			-e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt \
			-e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key \
			cli peer channel fetch oldest ${CHANNEL_NAME}.block -c ${CHANNEL_NAME} --orderer ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile ${ORDERER_TLS_CA}
		
		docker exec -e CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP \
			-e CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_URL}:7051 \
			-e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt \
			-e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key \
			-e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt \
			-e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/Admin@${ORG_URL}/msp \
			-e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt \
			-e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt \
			-e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key \
			cli peer channel join -b ${CHANNEL_NAME}.block

	done
done




############################################################## 
# UPDATING BASE ANCHOR PEERS
##############################################################

for ORG_NAME in "org1" "org2"; do

	printf "${C_BLUE}\n>>> UPDATING ${ORG_NAME} ANCHOR PEER\n${C_RESET}"

	ORG_URL=${ORG_NAME}.${PROJECT_URL}

	docker exec -e CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP \
		-e CORE_PEER_ADDRESS=peer0.${ORG_URL}:7051 \
		-e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.crt \
		-e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.key \
		-e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/ca.crt \
		-e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/Admin@${ORG_URL}/msp \
		cli peer channel update -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile ${ORDERER_TLS_CA} -c ${CHANNEL_NAME} -f /etc/hyperledger/configtx/${ORG_NAME^}MSPanchors.tx    

done




############################################################## 
# CONFIGURING DISCOVERY SERVICEs IN CLI CONTAINER
##############################################################

for ORG_NAME in "org1" "org2"; do

	printf "${C_BLUE}\n>>> CONFIGURING DISCOVERY SERVICE FOR ${ORG_NAME} IN THE CLI CONTAINER\n${C_RESET}"

	ORG_URL=${ORG_NAME}.${PROJECT_URL}
	
	PRIV_KEY_FILENAME=$(docker exec cli ls ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/User1@${ORG_URL}/msp/keystore/ | head -n 1)

	docker exec cli discover \
		--configFile discovery-conf-${ORG_NAME}.yaml \
		--tlsCert ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.crt \
		--tlsKey ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/server.key \
		--peerTLSCA ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/peer0.${ORG_URL}/tls/ca.crt \
		--userKey ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/User1@${ORG_URL}/msp/keystore/${PRIV_KEY_FILENAME} \
		--userCert ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/User1@${ORG_URL}/msp/signcerts/cert.pem \
		--MSP ${ORG_NAME^}MSP saveConfig

done