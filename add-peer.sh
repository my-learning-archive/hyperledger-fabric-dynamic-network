#!/bin/bash

C_RESET='\033[0m'
C_BLUE='\033[0;34m'




##############################################################
printf "${C_BLUE}\n>>> DEFINING INPUT VARIABLES\n${C_RESET}"

export PATH=~/Desktop/fabric-samples/bin:$PATH

PEER_NAME=$1 && echo ">>> PEER NAME: "${PEER_NAME}
ORG_NAME=$2 && echo ">>> ORG NAME: "${ORG_NAME}
PEER_7051_PORT=$3 && echo ">>> 7051 PEER PORT MAP: "${PEER_7051_PORT}
PEER_7053_PORT=$4 && echo ">>> 7053 PEER PORT MAP: "${PEER_7053_PORT}
COUCHDB_5984_PORT=$5 && echo ">>> 5984 COUCHDB PORT MAP: "${COUCHDB_5984_PORT}
CHANNEL_NAME=$6 && echo ">>> CHANNEL NAME: "${CHANNEL_NAME}
ADMIN_USERNAME=$7 && echo ">>> CA ADMIN USERNAME: "${ADMIN_USERNAME}
ADMIN_PASSWORD=$8 && echo ">>> CA ADMIN PASSWORD: "${ADMIN_PASSWORD}




##############################################################
printf "${C_BLUE}\n>>> VERIFYING IF ${ORG_NAME} EXISTS, AND IF ${PEER_NAME}.${ORG_NAME} ALREADY EXISTS\n${C_RESET}"

docker ps | grep -i ${ORG_NAME} &> /dev/null || {
  >&2 echo "${ORG_NAME} DOS NOT EXIST!"
  exit 1
}

docker ps | grep -i ${PEER_NAME}.${ORG_NAME} &> /dev/null && {
  >&2 echo "${PEER_NAME}.${ORG_NAME} ALREADY EXISTS!"
  exit 1
}




##############################################################
printf "${C_BLUE}\n>>> SORTING OUT DIRECTORIES AND GLOBAL VARIABLES, AND REMOVING PREVIOUS CONFIGURATIONS\n${C_RESET}"

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_NAME}.example.com
PEER_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/peers/${PEER_NAME}.${ORG_NAME}.example.com
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}.example.com

FABRIC_CA_CLIENT_DIR=/home/student/.fabric-ca-client

ORG_TEMP_TARGET=${SCRIPT}/${ORG_NAME}
CRYPTO_CONFIG_TARGET=${ORG_TEMP_TARGET}/crypto-config-${ORG_NAME}.yaml
DOCKER_COMPOSE_TARGET=${ORG_TEMP_TARGET}/docker-compose-${PEER_NAME}.${ORG_NAME}.yaml

echo y | rm -r ${ORG_TEMP_TARGET}
echo y | rm -r ${PEER_CRYPTO_MATERIAL_TARGET}
echo y | rm -r ${FABRIC_CA_CLIENT_DIR}

mkdir -p ${ORG_TEMP_TARGET}

cp ${FABRIC_TARGET}/.env ${ORG_TEMP_TARGET}
cd ${ORG_TEMP_TARGET}

CLI_CONTAINER=cli
ORDERER_CONTAINER_HOSTNAME_PORT=orderer.example.com:7050

CA_7054_PORT=$(yq '.services."ca.'${ORG_NAME}'.example.com".ports' ${FABRIC_TARGET}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')

if [[ ${CA_7054_PORT} == "l" ]]; then
  CA_7054_PORT=$(yq '.services."ca.'${ORG_NAME}'.example.com".ports' ${FABRIC_EXPAND_TARGET}/docker-compose-${ORG_NAME}.yaml | cut -c 4- | sed 's/[:].*//')
fi

if [[ ${CA_7054_PORT} == "l" ]]; then
  >&2 echo "COULD NOT OBTAIN THE PORT OF THE CA OF ${ORG_NAME}"
  exit 1
fi

CA_ADMIN_URL=https://${ADMIN_USERNAME}:${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
CA_PEER_URL=https://${PEER_NAME}:${PEER_NAME}pw@localhost:${CA_7054_PORT}




##############################################################
printf "${C_BLUE}\n>>> CREATING INITIAL docker-compose.yaml FOR ${ORG_NAME}\n${C_RESET}"

cat << EOF > ${DOCKER_COMPOSE_TARGET}
version: '2.2'

networks:
  basic:

services:
  ${PEER_NAME}.${ORG_NAME}.example.com:
    container_name: ${PEER_NAME}.${ORG_NAME}.example.com
    image: hyperledger/fabric-peer:\$IMAGE_TAG
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=${PEER_NAME}.${ORG_NAME}.example.com
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
      - CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_NAME}.example.com:7051
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_basic
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORG_NAME^}${PEER_NAME^}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=${PEER_NAME}.${ORG_NAME^}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=password
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=${PEER_NAME}.${ORG_NAME}.example.com:7051
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
printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR ${PEER_NAME}.${ORG_NAME}\n${C_RESET}"

echo -e "${C_BLUE}\n---> Enrolling the ca-admin${C_RESET}"
fabric-ca-client enroll \
  -u ${CA_ADMIN_URL} \
  --caname ca.example.com \
  --tls.certfiles ${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_NAME}.example.com-cert.pem

echo -e "${C_BLUE}\n---> Registering peer${C_RESET}"
fabric-ca-client register \
  --caname ca.example.com \
  --id.name ${PEER_NAME} \
  --id.secret ${PEER_NAME}pw \
  --id.type peer \
  --tls.certfiles ${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_NAME}.example.com-cert.pem

echo -e "${C_BLUE}\n---> Generating peer msp${C_RESET}"
fabric-ca-client enroll \
  -u ${CA_PEER_URL} \
  --caname ca.example.com \
  -M ${PEER_CRYPTO_MATERIAL_TARGET}/msp \
  --csr.hosts ${PEER_NAME}.${ORG_NAME}.example.com \
  --tls.certfiles ${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_NAME}.example.com-cert.pem

cp ${ORG_CRYPTO_MATERIAL_TARGET}/msp/config.yaml ${PEER_CRYPTO_MATERIAL_TARGET}/msp/config.yaml

echo -e "${C_BLUE}\n---> Generating peer tls${C_RESET}"
fabric-ca-client enroll \
  -u ${CA_PEER_URL} \
  --caname ca.example.com \
  -M ${PEER_CRYPTO_MATERIAL_TARGET}/tls \
  --enrollment.profile tls \
  --csr.hosts ${PEER_NAME}.${ORG_NAME}.example.com \
  --csr.hosts localhost \
  --tls.certfiles ${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_NAME}.example.com-cert.pem

cp ${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_NAME}.example.com-cert.pem ${PEER_CRYPTO_MATERIAL_TARGET}/msp/cacerts/ca.${ORG_NAME}.example.com-cert.pem
cp ${PEER_CRYPTO_MATERIAL_TARGET}/tls/tlscacerts/* ${PEER_CRYPTO_MATERIAL_TARGET}/tls/ca.crt
cp ${PEER_CRYPTO_MATERIAL_TARGET}/tls/signcerts/* ${PEER_CRYPTO_MATERIAL_TARGET}/tls/server.crt
cp ${PEER_CRYPTO_MATERIAL_TARGET}/tls/keystore/* ${PEER_CRYPTO_MATERIAL_TARGET}/tls/server.key




##############################################################
printf "${C_BLUE}\n>>> STARTING ${PEER_NAME}.${ORG_NAME} CONTAINERS\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d couchdb${ORG_NAME^}${PEER_NAME^} ${PEER_NAME}.${ORG_NAME}.example.com




##############################################################
printf "${C_BLUE}\n>>> ADDING ${PEER_NAME}.${ORG_NAME} TO CHANNEL ${CHANNEL_NAME}\n${C_RESET}"

CLI_SCRIPT=add-${PEER_NAME}.${ORG_NAME}.example.com-to-channel.sh

cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

export CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
export CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_NAME}.example.com:7051
export CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_NAME}.example.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_NAME}.example.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_NAME}.example.com/tls/ca.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_NAME}.example.com/tls/ca.crt
export CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_NAME}.example.com/tls/server.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_NAME}.example.com/tls/server.key
export CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/Admin@${ORG_NAME}.example.com/msp

peer channel fetch oldest ${CHANNEL_NAME}.block -c ${CHANNEL_NAME} --orderer ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}

sleep 10

peer channel join -b ${CHANNEL_NAME}.block
EOF

docker cp ./${CLI_SCRIPT} cli:/tmp/
docker exec cli chmod +x /tmp/${CLI_SCRIPT}
docker exec cli /tmp/${CLI_SCRIPT}




##############################################################
printf "${C_BLUE}\n>>> CLEANING UP ${ORG_TEMP_TARGET}\n${C_RESET}"

rm -r ${ORG_TEMP_TARGET}