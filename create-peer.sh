#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# INPUT VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-peer.sh:${C_BLUE}\n > DEFINING INPUT VARIABLE\n\n${C_RESET}"

set -x
PEER_NAME=$1
ORG_NAME=$2
PEER_7051_PORT=$3
PEER_7053_PORT=$4
COUCHDB_5984_PORT=$5
ADMIN_USERNAME=$6
ADMIN_PASSWORD=$7
{ set +x; } 2>/dev/null

[[ -z ${PEER_NAME} || -z ${ORG_NAME} || -z ${PEER_7051_PORT} || -z ${PEER_7053_PORT} || -z ${COUCHDB_5984_PORT} || -z ${ADMIN_USERNAME} || -z ${ADMIN_PASSWORD} ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} one or more mandatory arguments have not been provided!${C_RESET}"
  exit 1   
}




############################################################## 
# PROCESSING VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-peer.sh:${C_GRAY_ITALIC} ${PEER_NAME}.${ORG_NAME} ${C_BLUE}\n > PROCESSING VARIABLES, DIRECTORIES, AND NECESSARY VERIFICATIONS\n\n${C_RESET}"

# In the .env file
PROJECT_URL=${ENV_PROJECT_URL}
CLI_CONTAINER=${ENV_CLI_CONTAINER}
ORDERER_ENDPOINT=${ENV_ORDERER_ENDPOINT}

ORG_URL=${ORG_NAME}.${PROJECT_URL}

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}
PEER_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/peers/${PEER_NAME}.${ORG_URL}
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_URL}

TEMP_TARGET=${SCRIPT}/${ORG_NAME}_tmp
DOCKER_COMPOSE_TARGET=${TEMP_TARGET}/docker-compose-${PEER_NAME}.${ORG_NAME}.yaml

CA_7054_PORT=$(docker inspect ca.${ORG_URL} | grep HostPort | head -n 1 | awk '{print $2}' | tr -d '"')

CA_ADMIN_URL=https://${ADMIN_USERNAME}:${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
CA_PEER_URL=https://${PEER_NAME}:${PEER_NAME}pw@localhost:${CA_7054_PORT}




############################################################## 
# PERFORMING VERIFICATIONS
#
# 1. Does the specified org exist?
# 2. Does the specified peer already exist?
# 3. Are the provided admin credentials authorized?
##############################################################

[[ ${CA_7054_PORT} == '' ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} could not obtain the port of the ca of ${ORG_NAME} - check if ${ORG_NAME} exists and if its CA is running!${C_RESET}"
  exit 1
}

docker ps | grep -i ${PEER_NAME}.${ORG_NAME} &> /dev/null && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} ${PEER_NAME}.${ORG_NAME} already exists!${C_RESET}"
  exit 1
}

cd ${FABRIC_TARGET}
. create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}




############################################################## 
# PROCESSING DIRECTORIES
##############################################################

echo y | rm -r ${TEMP_TARGET} &> /dev/null
echo y | rm -r ${PEER_CRYPTO_MATERIAL_TARGET} &> /dev/null

mkdir -p ${TEMP_TARGET}
mkdir -p ${FABRIC_EXPAND_TARGET}

cp ${FABRIC_TARGET}/.env ${TEMP_TARGET}
cd ${TEMP_TARGET}




############################################################## 
# CREATING CONFIG FILES - docker-compose.yaml
##############################################################

printf "${C_BLUE_BOLD}\ncreate-peer.sh:${C_GRAY_ITALIC} ${PEER_NAME}.${ORG_NAME} ${C_BLUE}\n > CREATING docker-compose.yaml\n\n${C_RESET}"

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

printf "${C_BLUE_BOLD}\ncreate-peer.sh:${C_GRAY_ITALIC} ${PEER_NAME}.${ORG_NAME} ${C_BLUE}\n > GENERATING CRYPTO-MATERIALS\n\n${C_RESET}"

createEntity ${PEER_NAME} ${PEER_NAME} ${PEER_NAME}pw




############################################################## 
# STARTING SERVICES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-peer.sh:${C_GRAY_ITALIC} ${PEER_NAME}.${ORG_NAME} ${C_BLUE}\n > STARTING SERVICES\n\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d couchdb${ORG_NAME^}${PEER_NAME^} ${PEER_NAME}.${ORG_URL}




############################################################## 
# JOINING PEER TO APPLICATION CHANNELS
##############################################################

printf "${C_BLUE_BOLD}\ncreate-peer.sh:${C_GRAY_ITALIC} ${PEER_NAME}.${ORG_NAME} ${C_BLUE}\n > JOINING PEER TO APPLICATION CHANNELS\n\n${C_RESET}"

CLI_SCRIPT=add-${PEER_NAME}.${ORG_URL}-to-channel.sh

cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

function assumeRole {
  
  peer_name=\$1
  
  export CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
  export CORE_PEER_ADDRESS=\${peer_name}.${ORG_URL}:7051
  export CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/\${peer_name}.${ORG_URL}/tls/server.crt
  export CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/\${peer_name}.${ORG_URL}/tls/server.key
  export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/\${peer_name}.${ORG_URL}/tls/ca.crt
  export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/\${peer_name}.${ORG_URL}/tls/ca.crt
  export CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/\${peer_name}.${ORG_URL}/tls/server.crt
  export CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/\${peer_name}.${ORG_URL}/tls/server.key
  export CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/Admin@${ORG_URL}/msp
}

assumeRole peer0

org_channels_list=\$(peer channel list | sed 1d)

for channel_name in \${org_channels_list}; do

  assumeRole peer0

  channel_chaincodes_list=\$(peer lifecycle chaincode querycommitted --channelID \${channel_name} | tail -n +2 | tr -d "," | awk '{print \$2}')

  assumeRole ${PEER_NAME}

  echo -e "${C_BLUE}\nJoining peer to \${channel_name} application channel ...${C_RESET}"  
  peer channel fetch oldest \${channel_name}.block -c \${channel_name} --orderer ${ORDERER_ENDPOINT} --tls --cafile \${ORDERER_TLS_CA}
  sleep 10
  peer channel join -b \${channel_name}.block

  for chaincode in \${channel_chaincodes_list}; do
    echo -e "${C_BLUE}\nInstalling \${chaincode} chaincode ...${C_RESET}"
    peer lifecycle chaincode install \${chaincode}-package.tar.gz
  done
done
EOF

docker cp ./${CLI_SCRIPT} ${CLI_CONTAINER}:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




############################################################## 
# CLEANING UP
##############################################################

echo y | rm -r ${TEMP_TARGET}