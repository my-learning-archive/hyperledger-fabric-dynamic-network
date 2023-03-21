#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




##############################################################
# FUNCTIONS - START
##############################################################

function assumeRole {

  SUPRESS_VERBOSE=$2
  PEER_CONTAINER_NAME=$1
  OLDIFS=${IFS} && IFS='.'
  read -a PEER_CONTAINER_NAME_ARRAY <<< "${PEER_CONTAINER_NAME}"
  IFS=${OLDIFS}

  PEER_NAME=${PEER_CONTAINER_NAME_ARRAY[0]}
  ORG_NAME=${PEER_CONTAINER_NAME_ARRAY[1]}
  ORG_URL=${ORG_NAME}.${PROJECT_URL}
  CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_URL}

  [[ ${SUPRESS_VERBOSE} -eq 1 ]] || echo -e "${C_BLUE}\n---> Acting on behalf of ${PEER_NAME}.${ORG_NAME}${C_RESET}"

  _CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP
  _CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_URL}:7051
  _CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt
  _CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key
  _CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt
  _CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt
  _CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt
  _CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key
  _CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/users/Admin@${ORG_URL}/msp

  ENV=""
  ENV="${ENV} -e CORE_PEER_LOCALMSPID=${_CORE_PEER_LOCALMSPID}"
  ENV="${ENV} -e CORE_PEER_ADDRESS=${_CORE_PEER_ADDRESS} "
  ENV="${ENV} -e CORE_PEER_TLS_CERT_FILE=${_CORE_PEER_TLS_CERT_FILE} "
  ENV="${ENV} -e CORE_PEER_TLS_KEY_FILE=${_CORE_PEER_TLS_KEY_FILE} "
  ENV="${ENV} -e CORE_PEER_TLS_ROOTCERT_FILE=${_CORE_PEER_TLS_ROOTCERT_FILE} "
  ENV="${ENV} -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${_CORE_PEER_TLS_CLIENTROOTCAS_FILES} "
  ENV="${ENV} -e CORE_PEER_TLS_CLIENTCERT_FILE=${_CORE_PEER_TLS_CLIENTCERT_FILE} "
  ENV="${ENV} -e CORE_PEER_TLS_CLIENTKEY_FILE=${_CORE_PEER_TLS_CLIENTKEY_FILE} "
  ENV="${ENV} -e CORE_PEER_MSPCONFIGPATH=${_CORE_PEER_MSPCONFIGPATH} "
}

##############################################################
# FUNCTIONS - END
##############################################################




############################################################## 
# INPUT VARIABLES
##############################################################

printf "${C_BLUE}\n>>> DEFINING INPUT VARIABLES - deploy-chaincode.sh\n${C_RESET}"

set -x
CLI_CHAINCODE_DIR=$1
CHAINCODE_LANGUAGE=$2 
CHAINCODE_LABEL=$3 
CHAINCODE_VERSION=$4 
CHANNEL_NAME=$5 
{ set +x; } 2>/dev/null

ORGS_LIST=$({
  while (( "$#" )); do
    echo $6
    shift
  done
})




############################################################## 
# PROCESSING VARIABLES
##############################################################

printf "${C_BLUE}\n>>> SORTING OUT DIRECTORIES AND GLOBAL VARIABLES, AND REMOVING PREVIOUS CONFIGURATIONS\n${C_RESET}"

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand

FABRIC_CA_CLIENT_DIR=/home/student/.fabric-ca-client

TEMP_TARGET=${SCRIPT}/chaincode_tmp

echo y | rm -r ${TEMP_TARGET}

mkdir -p ${TEMP_TARGET}

cd ${TEMP_TARGET}

CLI_CONTAINER=cli
ORDERER_CONTAINER_HOSTNAME_PORT=orderer0.${PROJECT_URL}:7050

ORDERER_TLS_CA=$(docker exec ${CLI_CONTAINER} printenv ORDERER_TLS_CA)

PEERS_LIST=""
for ORG in ${ORGS_LIST}; do
  docker ps | grep -i ${ORG} &> /dev/null || {
    >&2 echo "${ORG} DOES NOT EXISTS!"
    exit 1
  }
  PEERS_LIST="${PEERS_LIST} "$(docker ps --format {{.Names}} | grep ^peer | grep $ORG | sort)
done

REPRESENTATIVE_PEERS_LIST=$(echo ${PEERS_LIST} | tr ' ' '\n' | grep ^peer0)

PEER_PARAMETERS=""
for PEER in ${PEERS_LIST}; do
  assumeRole ${PEER} 1
  PEER_PARAMETERS="${PEER_PARAMETERS} --peerAddresses ${_CORE_PEER_ADDRESS} --tlsRootCertFiles ${_CORE_PEER_TLS_ROOTCERT_FILE}"
done




############################################################## 
# VERIFICATIONS - CHAINCODE EXISTS?
##############################################################

printf "${C_BLUE}\n>>> VERIFYING IF CHAINCODE EXISTS\n${C_RESET}"

docker exec ${CLI_CONTAINER} ls ${CLI_CHAINCODE_DIR} &> /dev/null || {
  >&2 echo "${CLI_CHAINCODE_DIR} DOES NOT EXIST INSIDE THE ${CLI_CONTAINER} CONTAINER!"
  exit 1
}




############################################################## 
# PACKAGING CHAINCODE
##############################################################

printf "${C_BLUE}\n>>> PACKAGING CHAINCODE\n${C_RESET}"

assumeRole $(echo ${REPRESENTATIVE_PEERS_LIST} | awk '{print $1}')

[[ ${CHAINCODE_LANGUAGE} == "node" ]] && BUILD_COMMAND="npm install"
[[ ${CHAINCODE_LANGUAGE} == "golang" ]] && BUILD_COMMAND="GO111MODULE=on go mod vendor"

docker exec ${ENV} ${CLI_CONTAINER} bash -c "cd ${CLI_CHAINCODE_DIR}; ${BUILD_COMMAND}"

docker exec ${ENV} ${CLI_CONTAINER} \
  peer lifecycle chaincode package package.tar.gz \
    --path ${CLI_CHAINCODE_DIR} \
    --lang ${CHAINCODE_LANGUAGE} \
    --label ${CHAINCODE_LABEL}




############################################################## 
# INSTALLING CHAINCODE
##############################################################

printf "${C_BLUE}\n>>> INSTALLING CHAINCODE\n${C_RESET}"

for PEER in ${PEERS_LIST}; do

  assumeRole ${PEER}

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode install package.tar.gz

done




############################################################## 
# APPROVING CHAINCODE
##############################################################

printf "${C_BLUE}\n>>> APPROVING CHAINCODE\n${C_RESET}"

for PEER in ${REPRESENTATIVE_PEERS_LIST}; do

  assumeRole ${PEER}

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode queryinstalled >& ${TEMP_TARGET}/package-id-${PEER}

  PACKAGE_ID=$(sed -n "/${CHAINCODE_LABEL}/{s/^Package ID: //; s/, Label:.*$//; p;}" ${TEMP_TARGET}/package-id-${PEER})

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode approveformyorg \
      -o ${ORDERER_CONTAINER_HOSTNAME_PORT} \
      --tls --cafile ${ORDERER_TLS_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CHAINCODE_LABEL} \
      --version ${CHAINCODE_VERSION} \
      --package-id ${PACKAGE_ID} \
      --sequence ${CHAINCODE_VERSION}

done




############################################################## 
# COMMITING CHAINCODE
##############################################################

printf "${C_BLUE}\n>>> COMMITTING CHAINCODE\n${C_RESET}"

assumeRole $(echo ${REPRESENTATIVE_PEERS_LIST} | awk '{print $1}')

docker exec ${ENV} ${CLI_CONTAINER} \
  peer lifecycle chaincode commit \
    -o ${ORDERER_CONTAINER_HOSTNAME_PORT} \
    --tls --cafile ${ORDERER_TLS_CA} \
    --channelID ${CHANNEL_NAME} \
    --name ${CHAINCODE_LABEL} \
    --version ${CHAINCODE_VERSION} \
    --sequence ${CHAINCODE_VERSION} \
    ${PEER_PARAMETERS}





############################################################## 
# TESTING CHAINCODE
##############################################################

printf "${C_BLUE}\n>>> TESTING CHAINCODE\n${C_RESET}"

sleep 120

assumeRole $(echo ${REPRESENTATIVE_PEERS_LIST} | awk '{print $1}')

echo -e "${C_BLUE}\n---> Invoking chaincode: writing key1:value1${C_RESET}"
set -x
docker exec ${ENV} ${CLI_CONTAINER} \
  peer chaincode invoke \
    -o ${ORDERER_CONTAINER_HOSTNAME_PORT} \
    --tls --cafile ${ORDERER_TLS_CA} \
    --channelID ${CHANNEL_NAME} \
    --name ${CHAINCODE_LABEL} \
    ${PEER_PARAMETERS} \
    -c '{"function":"set","args":["key1", "value1"]}' --waitForEvent
{ set +x; } 2>/dev/null

echo -e "${C_BLUE}\n---> Querying chaincode: reading value of key1${C_RESET}"
set -x
docker exec ${ENV} ${CLI_CONTAINER} \
  peer chaincode query \
    --channelID ${CHANNEL_NAME} \
    --name ${CHAINCODE_LABEL} \
    --peerAddresses ${_CORE_PEER_ADDRESS} \
    --tlsRootCertFiles ${_CORE_PEER_TLS_ROOTCERT_FILE} \
    -c '{"function":"get","args":["key1"]}'
{ set +x; } 2>/dev/null




############################################################## 
# CLEAN UP
##############################################################

printf "${C_BLUE}\n>>> CLEANING UP ${TEMP_TARGET}\n${C_RESET}"

echo y | rm -r ${TEMP_TARGET}