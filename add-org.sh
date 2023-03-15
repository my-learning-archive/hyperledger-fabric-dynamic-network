#!/bin/bash

C_RESET='\033[0m'
C_BLUE='\033[0;34m'




##############################################################
printf "${C_BLUE}\n>>> DEFINING INPUT VARIABLES\n${C_RESET}"

export PATH=~/Desktop/fabric-samples/bin:$PATH

ORG_NAME=$1 && echo ">>> ORG NAME: "${ORG_NAME}
PEER_7051_PORT=$2 && echo ">>> 7051 PEER PORT MAP: "${PEER_7051_PORT}
PEER_7053_PORT=$3 && echo ">>> 7053 PEER PORT MAP: "${PEER_7053_PORT}
COUCHDB_5984_PORT=$4 && echo ">>> 5984 COUCHDB PORT MAP: "${COUCHDB_5984_PORT}
CA_7054_PORT=$5 && echo ">>> 7054 CA PORT MAP: "${CA_7054_PORT}
CHANNEL_NAME=$6 && echo ">>> CHANNEL NAME: "${CHANNEL_NAME}
ADMIN_USERNAME=$7 && echo ">>> CA ADMIN USERNAME: "${ADMIN_USERNAME}
ADMIN_PASSWORD=$8 && echo ">>> CA ADMIN PASSWORD: "${ADMIN_PASSWORD}




##############################################################
printf "${C_BLUE}\n>>> VERIFYING IF ${ORG_NAME} ALREADY EXISTS\n${C_RESET}"

docker ps | grep -i ${ORG_NAME} &> /dev/null && {
  >&2 echo "${ORG_NAME} ALREADY EXISTS!"
  exit 1
}




##############################################################
printf "${C_BLUE}\n>>> SORTING OUT DIRECTORIES AND GLOBAL VARIABLES, AND REMOVING PREVIOUS CONFIGURATIONS\n${C_RESET}"

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_NAME}.example.com
PEER0_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/peers/peer0.${ORG_NAME}.example.com
USER1_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/users/User1@${ORG_NAME}.example.com
ADMIN_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/users/Admin@${ORG_NAME}.example.com
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}.example.com

FABRIC_CA_CLIENT_DIR=/home/student/.fabric-ca-client

ORG_TEMP_TARGET=${SCRIPT}/${ORG_NAME}
CRYPTO_CONFIG_TARGET=${ORG_TEMP_TARGET}/crypto-config-${ORG_NAME}.yaml
DOCKER_COMPOSE_TARGET=${ORG_TEMP_TARGET}/docker-compose-${ORG_NAME}.yaml
CONFIGTX_TARGET=${ORG_TEMP_TARGET}/configtx-${ORG_NAME}.yaml
CA_SERVER_TARGET=${ORG_TEMP_TARGET}/fabric-ca-server-config-${ORG_NAME}.yaml
JSON_DEFINITIONS_TARGET=${ORG_TEMP_TARGET}/${ORG_NAME}_definition.json
NODEOUS_TARGET=${ORG_TEMP_TARGET}/nodeous-config-${ORG_NAME}.yaml

echo y | rm -r ${ORG_TEMP_TARGET}
echo y | rm -r ${ORG_CRYPTO_MATERIAL_TARGET}
echo y | rm -r ${FABRIC_CA_CLIENT_DIR}

mkdir -p ${ORG_TEMP_TARGET}
mkdir -p ${FABRIC_EXPAND_TARGET}
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

cp ${FABRIC_TARGET}/.env ${ORG_TEMP_TARGET}
cd ${ORG_TEMP_TARGET}

CLI_CONTAINER=cli 
ORDERER_CONTAINER_HOSTNAME_PORT=orderer.example.com:7050

CA_ADMIN_URL=https://${ADMIN_USERNAME}:${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
ORG_ADMIN_URL=https://${ORG_NAME}${ADMIN_USERNAME}:${ORG_NAME}${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
CA_PEER_URL=https://peer0:peer0pw@localhost:${CA_7054_PORT}
CA_USER_URL=https://user1:user1pw@localhost:${CA_7054_PORT}




##############################################################
printf "${C_BLUE}\n>>> CREATING INITIAL docker-compose.yaml FOR ${ORG_NAME}\n${C_RESET}"

cat << EOF > ${DOCKER_COMPOSE_TARGET}
version: '2.2'

networks:
  basic:

services:
  ca.${ORG_NAME}.example.com:
    container_name: ca.${ORG_NAME}.example.com    
    image: hyperledger/fabric-ca:\$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca.example.com
      - FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.${ORG_NAME}.example.com-cert.pem
      - FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/priv_sk
      - FABRIC_CA_SERVER_TLS_ENABLED=true
    ports:
      - "${CA_7054_PORT}:7054"
    command: sh -c 'fabric-ca-server start -b ${ADMIN_USERNAME}:${ADMIN_PASSWORD} -d'
    volumes:
      - ${ORG_CRYPTO_MATERIAL_TARGET}/ca/:/etc/hyperledger/fabric-ca-server-config
    networks:
      - basic
  
  peer0.${ORG_NAME}.example.com:
    container_name: peer0.${ORG_NAME}.example.com
    image: hyperledger/fabric-peer:\$IMAGE_TAG
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.${ORG_NAME}.example.com
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
      - CORE_PEER_ADDRESS=peer0.${ORG_NAME}.example.com:7051
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=\${COMPOSE_PROJECT_NAME}_basic
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORG_NAME^}Peer0:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer0.${ORG_NAME^}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=password
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${ORG_NAME}.example.com:7051
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: peer node start
    ports:
      - ${PEER_7051_PORT}:7051
      - ${PEER_7053_PORT}:7053
    volumes:
      - /var/run/:/host/var/run/
      - ${PEER0_CRYPTO_MATERIAL_TARGET}/msp:/etc/hyperledger/fabric/msp
      - ${PEER0_CRYPTO_MATERIAL_TARGET}/tls:/etc/hyperledger/fabric/tls
    networks:
      - basic
    depends_on:
      - couchdb${ORG_NAME^}Peer0

  couchdb${ORG_NAME^}Peer0:
    container_name: couchdb${ORG_NAME^}Peer0
    image: hyperledger/fabric-couchdb
    environment:
      - COUCHDB_USER=peer0.${ORG_NAME^}
      - COUCHDB_PASSWORD=password
    ports:
      - ${COUCHDB_5984_PORT}:5984
    networks:
      - basic
EOF

cp ${DOCKER_COMPOSE_TARGET} ${FABRIC_EXPAND_TARGET}/




##############################################################
printf "${C_BLUE}\n>>> CREATING INITIAL configtx.yaml FOR ${ORG_NAME}\n${C_RESET}"

cat << EOF > ${CONFIGTX_TARGET}        
Organizations:
    - &${ORG_NAME^}
      Name: ${ORG_NAME^}MSP
      ID: ${ORG_NAME^}MSP
      MSPDir: ${ORG_CRYPTO_MATERIAL_TARGET}/msp

      Policies:
          Readers:
              Type: Signature
              Rule: "OR('${ORG_NAME^}MSP.admin', '${ORG_NAME^}MSP.peer', '${ORG_NAME^}MSP.client')"
          Writers:
              Type: Signature
              Rule: "OR('${ORG_NAME^}MSP.admin', '${ORG_NAME^}MSP.client')"
          Admins:
              Type: Signature
              Rule: "OR('${ORG_NAME^}MSP.admin')"
          Endorsement:
              Type: Signature
              Rule: "OR('${ORG_NAME^}MSP.peer')"

      AnchorPeers:
          - Host: peer0.${ORG_NAME}.example.com
            Port: 7051
EOF

cp ${CONFIGTX_TARGET} ${FABRIC_EXPAND_TARGET}/




##############################################################
printf "${C_BLUE}\n>>> CREATING INITIAL fabric-ca-server-config.yaml FOR ${ORG_NAME}\n${C_RESET}"

cat << EOF > ${CA_SERVER_TARGET}    
version: 1.2.0
port: ${CA_7054_PORT}
debug: false
crlsizelimit: 512000

#############################################################################
#  TLS section for the server's listening port
#############################################################################
tls:
  enabled: true
  certfile:
  keyfile:
  clientauth:
    type: noclientcert
    certfiles:

#############################################################################
#  The CA section
#############################################################################
ca:
  name: ca.example.com
  keyfile:
  certfile:
  chainfile:

crl:
  expiry: 24h

#############################################################################
#  The registry section 
#############################################################################
registry:
  maxenrollments: -1

  identities:
     - name: ${ADMIN_USERNAME}
       pass: ${ADMIN_PASSWORD}
       type: client
       affiliation: ""
       attrs:
          hf.Registrar.Roles: "*"
          hf.Registrar.DelegateRoles: "*"
          hf.Revoker: true
          hf.IntermediateCA: true
          hf.GenCRL: true
          hf.Registrar.Attributes: "*"
          hf.AffiliationMgr: true

#############################################################################
#  Database section
#############################################################################
db:
  type: sqlite3
  datasource: fabric-ca-server.db
  tls:
      enabled: false
      certfiles:
      client:
        certfile:
        keyfile:

#############################################################################
#  LDAP section
#############################################################################
ldap:
   enabled: false
   url: ldap://<adminDN>:<adminPassword>@<host>:<port>/<base>
   tls:
      certfiles:
      client:
         certfile:
         keyfile:
   attribute:
      names: ['uid','member']
      converters:
         - name:
           value:
      maps:
         groups:
            - name:
              value:

#############################################################################
# Affiliations section
#############################################################################
#affiliations:
#   org1:
#      - department1
#      - department2
#   org2:
#      - department1

#############################################################################
#  Signing section
#############################################################################
signing:
    default:
      usage:
        - digital signature
      expiry: 8760h
    profiles:
      ca:
         usage:
           - cert sign
           - crl sign
         expiry: 43800h
         caconstraint:
           isca: true
           maxpathlen: 0
      tls:
         usage:
            - signing
            - key encipherment
            - server auth
            - client auth
            - key agreement
         expiry: 8760h

###########################################################################
#  Certificate Signing Request (CSR) section
###########################################################################
csr:
   cn: ca.${ORG_NAME}.example.com
   names:
      - C: US
        ST: "North Carolina"
        L: "Raleigh"
        O: ${ORG_NAME}.example.com
        OU:
   hosts:
     - localhost
     - ${ORG_NAME}.example.com
   ca:
      expiry: 131400h
      pathlength: 1

#############################################################################
# BCCSP (BlockChain Crypto Service Provider) section
#############################################################################
bccsp:
    default: SW
    sw:
        hash: SHA2
        security: 256
        filekeystore:
            keystore: msp/keystore

#############################################################################
# Multi CA section
#############################################################################

cacount:

cafiles:

#############################################################################
# Intermediate CA section
#############################################################################
intermediate:
  parentserver:
    url:
    caname:

  enrollment:
    hosts:
    profile:
    label:

  tls:
    certfiles:
    client:
      certfile:
      keyfile:
EOF

cp ${CA_SERVER_TARGET} ${FABRIC_EXPAND_TARGET}/
cp ${CA_SERVER_TARGET} ${ORG_CRYPTO_MATERIAL_TARGET}/ca/fabric-ca-server-config.yaml




##############################################################
printf "${C_BLUE}\n>>> STARTING THE CONTAINER OF THE CA OF ${ORG_NAME}\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d ca.${ORG_NAME}.example.com

sleep 10




##############################################################
printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR ${ORG_NAME}\n${C_RESET}"

cd ${FABRIC_TARGET}
. create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
createOrg
cd ${ORG_TEMP_TARGET}




##############################################################
printf "${C_BLUE}\n>>> CONFIGURING ${ORG_NAME} JSON DEFINITIONS\n${C_RESET}"

mv ${CONFIGTX_TARGET} ${ORG_TEMP_TARGET}/configtx.yaml
configtxgen -configPath ${ORG_TEMP_TARGET} -printOrg ${ORG_NAME^}MSP > ${JSON_DEFINITIONS_TARGET}
mv ${ORG_TEMP_TARGET}/configtx.yaml ${CONFIGTX_TARGET}

cp ${JSON_DEFINITIONS_TARGET} ${FABRIC_TARGET}/config/




##############################################################
printf "${C_BLUE}\n>>> STARTING ${ORG_NAME} CONTAINERS\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d couchdb${ORG_NAME^}Peer0 peer0.${ORG_NAME}.example.com




##############################################################
printf "${C_BLUE}\n>>> ADDING ${ORG_NAME} TO CHANNEL ${CHANNEL_NAME}\n${C_RESET}"

[[ -z ${CHANNEL_NAME} ]] && exit 0

CLI_SCRIPT=add-${ORG_NAME}-to-channel.sh
cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

peer channel fetch config blockFetchedConfig.pb -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA} -c ${CHANNEL_NAME}
configtxlator proto_decode --input blockFetchedConfig.pb --type common.Block | jq .data.data[0].payload.data.config > configBlock.json
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups":{"${ORG_NAME^}MSP":.[1]}}}}}' configBlock.json /etc/hyperledger/configtx/${ORG_NAME}_definition.json > configChanges.json
configtxlator proto_encode --input configBlock.json --type common.Config --output configBlock.pb
configtxlator proto_encode --input configChanges.json --type common.Config --output configChanges.pb
configtxlator compute_update --channel_id ${CHANNEL_NAME} --original configBlock.pb --updated configChanges.pb --output configProposal_${ORG_NAME^}.pb
configtxlator proto_decode --input configProposal_${ORG_NAME^}.pb --type common.ConfigUpdate | jq . > configProposal_${ORG_NAME^}.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"${CHANNEL_NAME}","type":2}},"data":{"config_update":'\$(cat configProposal_${ORG_NAME^}.json)'}}}' | jq . > ${ORG_NAME}SubmitReady.json
configtxlator proto_encode --input ${ORG_NAME}SubmitReady.json --type common.Envelope --output ${ORG_NAME}SubmitReady.pb

CRYPTO_ROOT=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/
for org in \$(ls \${CRYPTO_ROOT}); do 
  org_name=\${org%%.*}
  [[ \${org_name} != ${ORG_NAME} ]] && {
    echo \${org_name}
    export CORE_PEER_LOCALMSPID=\${org_name^}MSP
    export CORE_PEER_ADDRESS=peer0.\${org_name}.example.com:7051
    export CORE_PEER_TLS_CERT_FILE=\${CRYPTO_ROOT}/\${org_name}.example.com/peers/peer0.\${org_name}.example.com/tls/server.crt
    export CORE_PEER_TLS_KEY_FILE=\${CRYPTO_ROOT}/\${org_name}.example.com/peers/peer0.\${org_name}.example.com/tls/server.key
    export CORE_PEER_TLS_ROOTCERT_FILE=\${CRYPTO_ROOT}/\${org_name}.example.com/peers/peer0.\${org_name}.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=\${CRYPTO_ROOT}/\${org_name}.example.com/users/Admin@\${org_name}.example.com/msp
    peer channel signconfigtx -f ${ORG_NAME}SubmitReady.pb
  } 
done

peer channel update -f ${ORG_NAME}SubmitReady.pb -c ${CHANNEL_NAME} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}
EOF

docker cp ./${CLI_SCRIPT} cli:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




##############################################################
printf "${C_BLUE}\n>>> ADDING THE ANCHOR PEER OF ${ORG_NAME} TO CHANNEL ${CHANNEL_NAME}\n${C_RESET}"

CLI_SCRIPT=add-peer0.${ORG_NAME}.example.com-to-channel.sh

cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

export CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
export CORE_PEER_ADDRESS=peer0.${ORG_NAME}.example.com:7051
export CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_NAME}.example.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_NAME}.example.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_NAME}.example.com/tls/ca.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_NAME}.example.com/tls/ca.crt
export CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_NAME}.example.com/tls/server.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_NAME}.example.com/tls/server.key
export CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/Admin@${ORG_NAME}.example.com/msp

peer channel fetch 0 ${CHANNEL_NAME}.pb -c ${CHANNEL_NAME} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}

sleep 10

peer channel join -b ${CHANNEL_NAME}.block
EOF

docker cp ./${CLI_SCRIPT} cli:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




##############################################################
printf "${C_BLUE}\n>>> CLEANING UP ${ORG_TEMP_TARGET}\n${C_RESET}"

echo y | rm -r ${ORG_TEMP_TARGET}