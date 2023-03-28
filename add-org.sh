#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# INPUT VARIABLES 
##############################################################

printf "${C_BLUE}\n>>> DEFINING INPUT VARIABLES - add-org.sh\n${C_RESET}"

set -x
ORG_NAME=$1 
PEER_7051_PORT=$2 
PEER_7053_PORT=$3 
COUCHDB_5984_PORT=$4 
CA_7054_PORT=$5 
ADMIN_USERNAME=$6 
ADMIN_PASSWORD=$7
CHANNEL_NAME=$8
CHANNEL_ORG_NAME=$9
{ set +x; } 2>/dev/null




############################################################## 
# VERIFICATIONS - ORG ALREADY EXISTS?
##############################################################

printf "${C_BLUE}\n>>> VERIFYING IF ${ORG_NAME} ALREADY EXISTS\n${C_RESET}"

docker ps | grep -i ${ORG_NAME} &> /dev/null && {
  >&2 echo "${ORG_NAME} ALREADY EXISTS!"
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
PEER0_CRYPTO_MATERIAL_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/peers/peer0.${ORG_URL}
CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_URL}

ORG_TEMP_TARGET=${SCRIPT}/${ORG_NAME}_tmp
DOCKER_COMPOSE_TARGET=${ORG_TEMP_TARGET}/docker-compose-${ORG_NAME}.yaml
CONFIGTX_TARGET=${ORG_TEMP_TARGET}/configtx.yaml
CA_SERVER_TARGET=${ORG_TEMP_TARGET}/fabric-ca-server-config-${ORG_NAME}.yaml
ANCHOR_PEER_TX_TARGET=${ORG_TEMP_TARGET}/${ORG_NAME^}MSPanchors.tx
JSON_DEFINITIONS_TARGET=${ORG_TEMP_TARGET}/${ORG_NAME}_definition.json

echo y | rm -r ${ORG_TEMP_TARGET}
echo y | rm -r ${ORG_CRYPTO_MATERIAL_TARGET}

mkdir -p ${ORG_TEMP_TARGET}
mkdir -p ${FABRIC_EXPAND_TARGET}
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

cp ${FABRIC_TARGET}/.env ${ORG_TEMP_TARGET}
cd ${ORG_TEMP_TARGET}

CLI_CONTAINER=cli 
ORDERER_CONTAINER_HOSTNAME_PORT=orderer0.${PROJECT_URL}:7050
SYS_CHANNEL_NAME=system-channel

CA_ADMIN_URL=https://${ADMIN_USERNAME}:${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
ORG_ADMIN_URL=https://${ORG_NAME}${ADMIN_USERNAME}:${ORG_NAME}${ADMIN_PASSWORD}@localhost:${CA_7054_PORT}
CA_PEER_URL=https://peer0:peer0pw@localhost:${CA_7054_PORT}
CA_USER_URL=https://user1:user1pw@localhost:${CA_7054_PORT}
CHANNEL_ORG_URL=${CHANNEL_ORG_NAME}.${PROJECT_URL}

CHANNEL_ORGS_LIST=$(docker exec -it cli /bin/bash -c 'discover --configFile discovery-conf-'${CHANNEL_ORG_NAME}'.yaml peers --channel '${CHANNEL_NAME}' --server peer0.'${CHANNEL_ORG_URL}':7051' | grep MSPID | awk '{print $2}' | tr -d '",MSP' | tr '[:upper:]' '[:lower:]' | sort | uniq)




############################################################## 
# CREATING CONFIG FILES - docker-compose.yaml
##############################################################

printf "${C_BLUE}\n>>> CREATING INITIAL docker-compose.yaml FOR ${ORG_NAME}\n${C_RESET}"

cat << EOF > ${DOCKER_COMPOSE_TARGET}
version: '2.2'

networks:
  basic:

services:
  ca.${ORG_URL}:
    container_name: ca.${ORG_URL}    
    image: hyperledger/fabric-ca:\$IMAGE_TAG
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca.${PROJECT_URL}
      - FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.${ORG_URL}-cert.pem
      - FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/priv_sk
      - FABRIC_CA_SERVER_TLS_ENABLED=true
    ports:
      - "${CA_7054_PORT}:7054"
    command: sh -c 'fabric-ca-server start -b ${ADMIN_USERNAME}:${ADMIN_PASSWORD} -d'
    volumes:
      - ${ORG_CRYPTO_MATERIAL_TARGET}/ca/:/etc/hyperledger/fabric-ca-server-config
    networks:
      - basic
  
  peer0.${ORG_URL}:
    container_name: peer0.${ORG_URL}
    image: hyperledger/fabric-peer:\$IMAGE_TAG
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer0.${ORG_URL}
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
      - CORE_PEER_ADDRESS=peer0.${ORG_URL}:7051
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=\${COMPOSE_PROJECT_NAME}_basic
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORG_NAME^}Peer0:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer0.${ORG_NAME^}
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=password
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${ORG_URL}:7051
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
# CREATING CONFIG FILES - configtx.yaml
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
          - Host: peer0.${ORG_URL}
            Port: 7051
EOF

cp ${CONFIGTX_TARGET} ${FABRIC_EXPAND_TARGET}/configtx-${CHANNEL_NAME}-${ORG_NAME}.yaml




############################################################## 
# CREATING CONFIG FILES - fabric-ca-server-config.yaml
##############################################################

printf "${C_BLUE}\n>>> CREATING INITIAL fabric-ca-server-config.yaml FOR ${ORG_NAME}\n${C_RESET}"

cat << EOF > ${CA_SERVER_TARGET}    
version: 1.2.0
port: ${CA_7054_PORT}
debug: false
crlsizelimit: 512000

tls:
  enabled: true
  certfile:
  keyfile:
  clientauth:
    type: noclientcert
    certfiles:

ca:
  name: ca.${PROJECT_URL}
  keyfile:
  certfile:
  chainfile:

crl:
  expiry: 24h

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

db:
  type: sqlite3
  datasource: fabric-ca-server.db
  tls:
      enabled: false
      certfiles:
      client:
        certfile:
        keyfile:

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

csr:
   cn: ca.${ORG_URL}
   names:
      - C: US
        ST: "North Carolina"
        L: "Raleigh"
        O: ${ORG_URL}
        OU:
   hosts:
     - localhost
     - ${ORG_URL}
   ca:
      expiry: 131400h
      pathlength: 1

bccsp:
    default: SW
    sw:
        hash: SHA2
        security: 256
        filekeystore:
            keystore: msp/keystore

cacount:

cafiles:

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
# GENERATING CERTIFICATES
##############################################################

printf "${C_BLUE}\n>>> STARTING THE CONTAINER OF THE CA OF ${ORG_NAME}\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d ca.${ORG_URL}

sleep 10

printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR ${ORG_NAME}\n${C_RESET}"

cd ${FABRIC_TARGET}
. create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
createOrg
createUser "client" "User1" "user1" "user1pw"
createEntity "peer0" "peer0" "peer0pw"
cd ${ORG_TEMP_TARGET}




############################################################## 
# CREATING ORG JSON DEFINITIONS
##############################################################

printf "${C_BLUE}\n>>> CONFIGURING ${ORG_NAME} JSON DEFINITIONS\n${C_RESET}"

configtxgen -configPath ${ORG_TEMP_TARGET} -printOrg ${ORG_NAME^}MSP > ${JSON_DEFINITIONS_TARGET}

cp ${JSON_DEFINITIONS_TARGET} ${FABRIC_TARGET}/config/




############################################################## 
# STARTING CONTAINERS
##############################################################

printf "${C_BLUE}\n>>> STARTING ${ORG_NAME} CONTAINERS\n${C_RESET}"

docker compose -f ${DOCKER_COMPOSE_TARGET} up -d couchdb${ORG_NAME^}Peer0 peer0.${ORG_URL}




############################################################## 
# JOINING ORG TO CONSORTIUM
##############################################################

printf "${C_BLUE}\n>>> JOINING ${ORG_NAME} TO CONSORTIUM\n${C_RESET}"

CLI_SCRIPT=join-${ORG_NAME}-to-consortium.sh
cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

crypto_root=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations

export CORE_PEER_LOCALMSPID=OrdererMSP
export CORE_PEER_ADDRESS=orderer0.${CHANNEL_ORG_URL}:7050
export CORE_PEER_TLS_CERT_FILE=\${crypto_root}/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=\${crypto_root}/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=\${crypto_root}/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=\${crypto_root}/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTCERT_FILE=\${crypto_root}/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/server.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=\${crypto_root}/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/server.key
export CORE_PEER_MSPCONFIGPATH=\${crypto_root}/${PROJECT_URL}/users/Admin@${PROJECT_URL}/msp

block_fetched_config_pb=blockFetchedConfig-${SYS_CHANNEL_NAME}-${ORG_NAME}.pb
config_block_json=configBlock-${SYS_CHANNEL_NAME}-${ORG_NAME}.json
config_block_pb=configBlock-${SYS_CHANNEL_NAME}-${ORG_NAME}.pb
config_changes_json=configChanges-${SYS_CHANNEL_NAME}-${ORG_NAME}.json
config_changes_pb=configChanges-${SYS_CHANNEL_NAME}-${ORG_NAME}.pb
config_proposal_json=configProposal-${SYS_CHANNEL_NAME}-${ORG_NAME}.json
config_proposal_pb=configProposal-${SYS_CHANNEL_NAME}-${ORG_NAME}.pb
submit_ready_json=submitReady-${SYS_CHANNEL_NAME}-${ORG_NAME}.json
submit_ready_pb=submitReady-${SYS_CHANNEL_NAME}-${ORG_NAME}.pb

peer channel fetch config \${block_fetched_config_pb} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA} -c ${SYS_CHANNEL_NAME}
configtxlator proto_decode --input \${block_fetched_config_pb} --type common.Block | jq .data.data[0].payload.data.config > \${config_block_json}

jq -s '.[0] * {"channel_group":{"groups":{"Consortiums":{"groups":{"SampleConsortium":{"groups":{"${ORG_NAME^}MSP":.[1]}}}}}}}' \${config_block_json} /etc/hyperledger/configtx/${ORG_NAME}_definition.json > \${config_changes_json}

configtxlator proto_encode --input \${config_block_json} --type common.Config --output \${config_block_pb}
configtxlator proto_encode --input \${config_changes_json} --type common.Config --output \${config_changes_pb}
configtxlator compute_update --channel_id ${SYS_CHANNEL_NAME} --original \${config_block_pb} --updated \${config_changes_pb} --output \${config_proposal_pb}
configtxlator proto_decode --input \${config_proposal_pb} --type common.ConfigUpdate | jq . > \${config_proposal_json}
echo '{"payload":{"header":{"channel_header":{"channel_id":"${SYS_CHANNEL_NAME}","type":2}},"data":{"config_update":'\$(cat \${config_proposal_json})'}}}' | jq . > \${submit_ready_json}
configtxlator proto_encode --input \${submit_ready_json} --type common.Envelope --output \${submit_ready_pb}

peer channel update -f \${submit_ready_pb} -c ${SYS_CHANNEL_NAME} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}
EOF

docker cp ./${CLI_SCRIPT} cli:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




############################################################## 
# JOINING ORG TO APPLICATION CHANNEL
##############################################################

[[ -z ${CHANNEL_NAME} ]] && exit 0
[[ -z ${CHANNEL_ORG_NAME} ]] && {
  >&2 echo "YOU DID NOT SPECIFY AN ORG FOR THE CURRENT CHANNEL"
  exit 1
}

printf "${C_BLUE}\n>>> JOINING ${ORG_NAME} TO CHANNEL ${CHANNEL_NAME}\n${C_RESET}"

CLI_SCRIPT=join-${ORG_NAME}-to-channel.sh
cat << EOF > ./${CLI_SCRIPT}
#!/bin/bash

channel_orgs_list=\$(discover --configFile discovery-conf-${CHANNEL_ORG_NAME}.yaml peers --channel ${CHANNEL_NAME} --server peer0.${CHANNEL_ORG_URL}:7051 | grep MSPID | awk '{print \$2}' | tr -d '",MSP' | tr '[:upper:]' '[:lower:]' | sort | uniq)

crypto_root=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations

export CORE_PEER_LOCALMSPID=${CHANNEL_ORG_NAME^}MSP
export CORE_PEER_ADDRESS=peer0.${CHANNEL_ORG_URL}:7051
export CORE_PEER_TLS_CERT_FILE=\${crypto_root}/${CHANNEL_ORG_URL}/peers/peer0.${CHANNEL_ORG_URL}/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=\${crypto_root}/${CHANNEL_ORG_URL}/peers/peer0.${CHANNEL_ORG_URL}/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=\${crypto_root}/${CHANNEL_ORG_URL}/peers/peer0.${CHANNEL_ORG_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTROOTCAS_FILES=\${crypto_root}/${CHANNEL_ORG_URL}/peers/peer0.${CHANNEL_ORG_URL}/tls/ca.crt
export CORE_PEER_TLS_CLIENTCERT_FILE=\${crypto_root}/${CHANNEL_ORG_URL}/peers/peer0.${CHANNEL_ORG_URL}/tls/server.crt
export CORE_PEER_TLS_CLIENTKEY_FILE=\${crypto_root}/${CHANNEL_ORG_URL}/peers/peer0.${CHANNEL_ORG_URL}/tls/server.key
export CORE_PEER_MSPCONFIGPATH=\${crypto_root}/${CHANNEL_ORG_URL}/users/Admin@${CHANNEL_ORG_URL}/msp

block_fetched_config_pb=blockFetchedConfig-${CHANNEL_NAME}-${ORG_NAME}.pb
config_block_json=configBlock-${CHANNEL_NAME}-${ORG_NAME}.json
config_block_pb=configBlock-${CHANNEL_NAME}-${ORG_NAME}.pb
config_changes_json=configChanges-${CHANNEL_NAME}-${ORG_NAME}.json
config_changes_pb=configChanges-${CHANNEL_NAME}-${ORG_NAME}.pb
config_proposal_json=configProposal-${CHANNEL_NAME}-${ORG_NAME}.json
config_proposal_pb=configProposal-${CHANNEL_NAME}-${ORG_NAME}.pb
submit_ready_json=submitReady-${CHANNEL_NAME}-${ORG_NAME}.json
submit_ready_pb=submitReady-${CHANNEL_NAME}-${ORG_NAME}.pb

peer channel fetch config \${block_fetched_config_pb} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA} -c ${CHANNEL_NAME}
configtxlator proto_decode --input \${block_fetched_config_pb} --type common.Block | jq .data.data[0].payload.data.config > \${config_block_json}

jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups":{"${ORG_NAME^}MSP":.[1]}}}}}' \${config_block_json} /etc/hyperledger/configtx/${ORG_NAME}_definition.json > \${config_changes_json}

configtxlator proto_encode --input \${config_block_json} --type common.Config --output \${config_block_pb}
configtxlator proto_encode --input \${config_changes_json} --type common.Config --output \${config_changes_pb}
configtxlator compute_update --channel_id ${CHANNEL_NAME} --original \${config_block_pb} --updated \${config_changes_pb} --output \${config_proposal_pb}
configtxlator proto_decode --input \${config_proposal_pb} --type common.ConfigUpdate | jq . > \${config_proposal_json}
echo '{"payload":{"header":{"channel_header":{"channel_id":"${CHANNEL_NAME}","type":2}},"data":{"config_update":'\$(cat \${config_proposal_json})'}}}' | jq . > \${submit_ready_json}
configtxlator proto_encode --input \${submit_ready_json} --type common.Envelope --output \${submit_ready_pb}

for org_name in \${channel_orgs_list}; do
  org_name=\$(echo \${org_name} | sed 's/\r$//')
  org_url=\${org_name}.${PROJECT_URL}
  [[ \${org_name} != ${ORG_NAME} ]] && {
    export CORE_PEER_LOCALMSPID=\${org_name^}MSP
    export CORE_PEER_ADDRESS=peer0.\${org_url}:7051
    export CORE_PEER_TLS_CERT_FILE=\${crypto_root}/\${org_url}/peers/peer0.\${org_url}/tls/server.crt
    export CORE_PEER_TLS_KEY_FILE=\${crypto_root}/\${org_url}/peers/peer0.\${org_url}/tls/server.key
    export CORE_PEER_TLS_ROOTCERT_FILE=\${crypto_root}/\${org_url}/peers/peer0.\${org_url}/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=\${crypto_root}/\${org_url}/users/Admin@\${org_url}/msp
    peer channel signconfigtx -f \${submit_ready_pb}
  } 
done

peer channel update -f \${submit_ready_pb} -c ${CHANNEL_NAME} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}
EOF

docker cp ./${CLI_SCRIPT} ${CLI_CONTAINER}:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




############################################################## 
# JOINING ANCHOR PEER TO APPLICATION CHANNEL
##############################################################

printf "${C_BLUE}\n>>> JOINING THE ANCHOR PEER OF ${ORG_NAME} TO CHANNEL ${CHANNEL_NAME}\n${C_RESET}"

CLI_SCRIPT=join-peer0.${ORG_URL}-to-channel.sh

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

peer channel fetch oldest ${CHANNEL_NAME}.block -c ${CHANNEL_NAME} -o ${ORDERER_CONTAINER_HOSTNAME_PORT} --tls --cafile \${ORDERER_TLS_CA}

sleep 10

peer channel join -b ${CHANNEL_NAME}.block
EOF

docker cp ./${CLI_SCRIPT} ${CLI_CONTAINER}:/tmp/
docker exec ${CLI_CONTAINER} chmod +x /tmp/${CLI_SCRIPT}
docker exec ${CLI_CONTAINER} /tmp/${CLI_SCRIPT}




############################################################## 
# CONFIGURING DISCOVERY SERVICE IN CLI CONTAINER
##############################################################

printf "${C_BLUE}\n>>> CONFIGURING DISCOVERY SERVICE FOR ${ORG_NAME} IN THE CLI CONTAINER\n${C_RESET}"

PRIV_KEY_FILENAME=$(docker exec ${CLI_CONTAINER} ls ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/User1@${ORG_URL}/msp/keystore/ | head -n 1)

docker exec ${CLI_CONTAINER} discover \
	--configFile discovery-conf-${ORG_NAME}.yaml \
	--tlsCert ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/server.crt \
	--tlsKey ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/server.key \
	--peerTLSCA ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/peer0.${ORG_URL}/tls/ca.crt \
	--userKey ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/User1@${ORG_URL}/msp/keystore/${PRIV_KEY_FILENAME} \
	--userCert ${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/User1@${ORG_URL}/msp/signcerts/cert.pem \
	--MSP ${ORG_NAME^}MSP saveConfig




############################################################## 
# CLEAN UP
##############################################################

printf "${C_BLUE}\n>>> CLEANING UP ${ORG_TEMP_TARGET}\n${C_RESET}"

echo y | rm -r ${ORG_TEMP_TARGET}