#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# INPUT VARIABLES
##############################################################

printf "${C_BLUE}\n>>> DEFINING INPUT VARIABLE - add-peer.sh\n${C_RESET}"

set -x
PEER_NAME=$1
ORG_NAME=$2
PEER_7051_PORT=$3
PEER_7053_PORT=$4
COUCHDB_5984_PORT=$5
ADMIN_USERNAME=$6
ADMIN_PASSWORD=$7
{ set +x; } 2>/dev/null




############################################################## 
# VERIFICATIONS - ORG EXISTS? PEER ALREADY EXISTS?
##############################################################

printf "${C_BLUE}\n>>> VERIFYING IF ${PEER_NAME}.${ORG_NAME} ALREADY EXISTS\n${C_RESET}"

docker ps | grep -i ${PEER_NAME}.${ORG_NAME} &> /dev/null && {
  >&2 echo "${PEER_NAME}.${ORG_NAME} ALREADY EXISTS!"
  exit 1
}




############################################################## 
# PROCESSING VARIABLES
##############################################################

printf "${C_BLUE}\n>>> SORTING OUT DIRECTORIES AND GLOBAL VARIABLES, AND REMOVING PREVIOUS CONFIGURATIONS\n${C_RESET}"

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file
ORG_URL=${ORG_NAME}.${PROJECT_URL}

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}
PEER_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/peers/${PEER_NAME}.${ORG_URL}
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_URL}

ORG_TEMP_TARGET=${SCRIPT}/${ORG_NAME}
DOCKER_COMPOSE_TARGET=${ORG_TEMP_TARGET}/docker-compose-${PEER_NAME}.${ORG_NAME}.yaml

echo y | rm -r ${ORG_TEMP_TARGET}
echo y | rm -r ${PEER_CRYPTO_MATERIAL_TARGET}

mkdir -p ${ORG_TEMP_TARGET}
mkdir -p ${FABRIC_EXPAND_TARGET}

cp ${FABRIC_TARGET}/.env ${ORG_TEMP_TARGET}
cd ${ORG_TEMP_TARGET}

CLI_CONTAINER=cli
ORDERER_CONTAINER_HOSTNAME_PORT=orderer0.${PROJECT_URL}:7050

CA_7054_PORT=$(docker inspect ca.${ORG_URL} | grep HostPort | head -n 1 | awk '{print $2}' | tr -d '"')
[[ ! $? -eq 0 ]] && {
  >&2 echo "COULD NOT OBTAIN THE PORT OF THE CA OF ${ORG_NAME} - CHECK IF ORG EXISTS"
  exit 1
}

CA_ADMIN_URL=https://${ADMIN_USERNAME}:${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
CA_PEER_URL=https://${PEER_NAME}:${PEER_NAME}pw@localhost:${CA_7054_PORT}




############################################################## 
# VERIFICATIONS - AUTHORIZATION
##############################################################

printf "${C_BLUE}\n>>> VERIFYING AUTHORIZATION OF ${ADMIN_USERNAME}\n${C_RESET}"

cd ${FABRIC_TARGET}
. create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
cd ${ORG_TEMP_TARGET}




############################################################## 
# CREATING CONFIG FILES - docker-compose.yaml
##############################################################

printf "${C_BLUE}\n>>> CREATING INITIAL docker-compose.yaml FOR ${PEER_NAME}.${ORG_NAME}\n${C_RESET}"

cat << EOF > ${DOCKER_COMPOSE_TARGET}
version: '2.2'

networks:
  basic:

services:
  ${PEER_NAME}.${ORG_URL}:
    container_name: ${PEER_NAME}.${ORG_URL}
    image: hyperledger/fabric-peer:\$IMAGE_TAG
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=${PEER_NAME}.${ORG_URL}
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
      - CORE_PEER_TLS_CLIENTROOTCAS_FILES=/etc/hyperledger/fabric/tls/ca.crt
      - CORE_PEER_TLS_CLIENTCERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_CLIENTKEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
      - CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_URL}:7051
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=\${COMPOSE_PROJECT_NAME}_basic
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORG_NAME^}${PEER_NAME^}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=${PEER_NAME}.${ORG_NAME^}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=password
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=${PEER_NAME}.${ORG_URL}:7051
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: peer node start
    ports:
      - ${PEER_7051_PORT}:7051
      - ${PEER_7053_PORT}:7053
    volumes:
      - /var/run/:/host/var/run/
      - ${PEER_CRYPTO_MATERIAL_TARGET}/msp:/etc/hyperledger/fabric/msp
      - ${PEER_CRYPTO_MATERIAL_TARGET}/tls:/etc/hyperledger/fabric/tls
    networks:
      - basic
    depends_on:
      - couchdb${ORG_NAME^}${PEER_NAME^}

  couchdb${ORG_NAME^}${PEER_NAME^}:
    container_name: couchdb${ORG_NAME^}${PEER_NAME^}
    image: hyperledger/fabric-couchdb
    environment:
      - COUCHDB_USER=${PEER_NAME}.${ORG_NAME^}
      - COUCHDB_PASSWORD=password
    ports:
      - ${COUCHDB_5984_PORT}:5984
    networks:
      - basic
EOF

cp ${DOCKER_COMPOSE_TARGET} ${FABRIC_EXPAND_TARGET}/




############################################################## 
# GENERATING CERTIFICATES
##############################################################

printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR ${PEER_NAME}.${ORG_NAME}\n${C_RESET}"

createEntity ${PEER_NAME} ${PEER_NAME} ${PEER_NAME}pw




############################################################## 
# STARTING CONTAINERS
##############################################################

printf "${C_BLUE}\n>>> STARTING ${PEER_NAME}.${ORG_NAME} CONTAINERS\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d couchdb${ORG_NAME^}${PEER_NAME^} ${PEER_NAME}.${ORG_URL}




############################################################## 
# JOINING PEER TO APPLICATION CHANNEL
##############################################################

printf "${C_BLUE}\n>>> JOINING ${PEER_NAME}.${ORG_NAME} TO THE APPLICATION CHANNELS OF ${ORG_NAME}\n${C_RESET}"

CLI_SCRIPT=add-${PEER_NAME}.${ORG_URL}-to-channel.sh

cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

export CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
export CORE_PEER_ADDRESS=peer0.${ORG_URL}:7051
export CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/server.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/server.key
export CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/Admin@${ORG_URL}/msp

org_channels_list=\$(peer channel list | sed 1d)

export CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
export CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_URL}:7051
export CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key
export CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/Admin@${ORG_URL}/msp

for channel_name in \${org_channels_list}; do
  peer channel fetch oldest \${channel_name}.block -c \${channel_name} --orderer ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}
  sleep 10
  peer channel join -b \${channel_name}.block
done
EOF

docker cp ./${CLI_SCRIPT} ${CLI_CONTAINER}:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




############################################################## 
# CLEAN UP
##############################################################

printf "${C_BLUE}\n>>> CLEANING UP ${ORG_TEMP_TARGET}\n${C_RESET}"

echo y | rm -r ${ORG_TEMP_TARGET}