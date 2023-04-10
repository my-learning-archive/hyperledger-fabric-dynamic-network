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

  [[ ${SUPRESS_VERBOSE} -eq 1 ]] || echo -e "${C_BLUE}\nActing on behalf of ${PEER_NAME}.${ORG_NAME} ...${C_RESET}"

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

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_BLUE}\n > DEFINING INPUT VARIABLES\n\n${C_RESET}"

set -x
CLI_CHAINCODE_DIR=$1
CHAINCODE_LANGUAGE=$2 
CHAINCODE_LABEL=$3 
CHAINCODE_VERSION=$4 
CHANNEL_NAME=$5
CHANNEL_ORG_NAME=$6
COLLECTIONS_CONFIG=${7:-"NA"}
SIGNATURE_POLICY=${8:-"NA"}
{ set +x; } 2>/dev/null

[[ -z ${CLI_CHAINCODE_DIR} || -z ${CHAINCODE_LANGUAGE} || -z ${CHAINCODE_LABEL} || -z ${CHAINCODE_VERSION} || -z ${CHANNEL_NAME} || -z ${CHANNEL_ORG_NAME} || -z ${CHANNEL_ORG_NAME} || -z ${COLLECTIONS_CONFIG} || -z ${SIGNATURE_POLICY} ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} one or more mandatory arguments have not been provided!${C_RESET}"
  exit 1   
}




############################################################## 
# PROCESSING VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_GRAY_ITALIC} ${CHAINCODE_LABEL}:${CHAINCODE_VERSION} ${C_BLUE}\n > PROCESSING VARIABLES, DIRECTORIES, AND NECESSARY VERIFICATIONS\n\n${C_RESET}"

# In the .env file
PROJECT_URL=${ENV_PROJECT_URL} 
CLI_CONTAINER=${ENV_CLI_CONTAINER}
ORDERER_ENDPOINT=${ENV_ORDERER_ENDPOINT}

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand

TEMP_TARGET=${SCRIPT}/${CHAINCODE_LABEL}_tmp

ORDERER_TLS_CA=$(docker exec ${CLI_CONTAINER} printenv ORDERER_TLS_CA)

CHANNEL_ORG_URL=${CHANNEL_ORG_NAME}.${PROJECT_URL}
CHANNEL_ORGS_LIST=$(docker exec -it ${CLI_CONTAINER} /bin/bash -c 'discover --configFile discovery-conf-'${CHANNEL_ORG_NAME}'.yaml config --channel '${CHANNEL_NAME}' --server peer0.'${CHANNEL_ORG_URL}':7051' | grep name | grep -v "Orderer" | awk '{print $2}' | tr -d '",MSP' | tr '[:upper:]' '[:lower:]' | sort | uniq)

PEERS_LIST=""
for ORG in ${CHANNEL_ORGS_LIST}; do
  ORG=$(echo ${ORG} |  sed 's/\r$//')
  PEERS_LIST="${PEERS_LIST} "$(docker ps --format {{.Names}} | grep ^peer | grep ${ORG} | sort)
done

REPRESENTATIVE_PEERS_LIST=$(echo ${PEERS_LIST} | tr ' ' '\n' | grep ^peer0)

PEER_PARAMETERS=""
for PEER in ${PEERS_LIST}; do
  assumeRole ${PEER} 1
  PEER_PARAMETERS="${PEER_PARAMETERS} --peerAddresses ${_CORE_PEER_ADDRESS} --tlsRootCertFiles ${_CORE_PEER_TLS_ROOTCERT_FILE}"
done

[[ ${COLLECTIONS_CONFIG} == "NA" ]] || {
  COLLECTIONS_CONFIG_FLAG="--collections-config ${CLI_CHAINCODE_DIR}/${COLLECTIONS_CONFIG}"
}

[[ ${SIGNATURE_POLICY} == "NA" ]] || {
  SIGNATURE_POLICY_FLAG="--signature-policy ${SIGNATURE_POLICY}"
}




############################################################## 
# PERFORMING VERIFICATIONS
#
# 1. Does the specified chaincode directory exist?
# 2. If collections configuration file is specified, does 
#    it exist?
# 3. Does the specified channel exist? Was a corresponding
#    org specified, and does it belong to the channel?
##############################################################

docker exec ${CLI_CONTAINER} ls ${CLI_CHAINCODE_DIR} &> /dev/null || {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} ${CLI_CHAINCODE_DIR} does not exist inside the ${CLI_CONTAINER} container!${C_RESET}"
  exit 1
}

[[ ${COLLECTIONS_CONFIG} == "NA" ]] || {
  docker exec ${CLI_CONTAINER} ls ${CLI_CHAINCODE_DIR}/${COLLECTIONS_CONFIG} &> /dev/null || {
    >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} ${CLI_CHAINCODE_DIR}/${COLLECTIONS_CONFIG} does not exist inside the ${CLI_CONTAINER} container!${C_RESET}"
    exit 1
  }
}

[[ ${PEERS_LIST} == "" ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} could not get the list of peers in the ${CHANNEL_NAME} channel - check if ${CHANNEL_NAME} exists or if ${CHANNEL_ORG_NAME} belongs to it!${C_RESET}"
  exit 1  
}




############################################################## 
# PROCESSING DIRECTORIES
##############################################################

echo y | rm -r ${TEMP_TARGET} &> /dev/null

mkdir -p ${TEMP_TARGET}

cd ${TEMP_TARGET}




############################################################## 
# PACKAGING CHAINCODE
##############################################################

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_GRAY_ITALIC} ${CHAINCODE_LABEL}:${CHAINCODE_VERSION} ${C_BLUE}\n > PACKAGING CHAINCODE\n\n${C_RESET}"

assumeRole $(echo ${REPRESENTATIVE_PEERS_LIST} | awk '{print $1}')

[[ ${CHAINCODE_LANGUAGE} == "node" ]] && BUILD_COMMAND="npm install"
[[ ${CHAINCODE_LANGUAGE} == "golang" ]] && BUILD_COMMAND="GO111MODULE=on go mod vendor"

docker exec ${ENV} ${CLI_CONTAINER} bash -c "cd ${CLI_CHAINCODE_DIR}; ${BUILD_COMMAND}"

docker exec ${ENV} ${CLI_CONTAINER} \
  peer lifecycle chaincode package ${CHAINCODE_LABEL}-package.tar.gz \
    --path ${CLI_CHAINCODE_DIR} \
    --lang ${CHAINCODE_LANGUAGE} \
    --label ${CHAINCODE_LABEL}




############################################################## 
# INSTALLING CHAINCODE
##############################################################

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_GRAY_ITALIC} ${CHAINCODE_LABEL}:${CHAINCODE_VERSION} ${C_BLUE}\n > INSTALLING CHAINCODE\n\n${C_RESET}"

for PEER in ${PEERS_LIST}; do

  assumeRole ${PEER}

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode install ${CHAINCODE_LABEL}-package.tar.gz

done




############################################################## 
# APPROVING CHAINCODE
##############################################################

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_GRAY_ITALIC} ${CHAINCODE_LABEL}:${CHAINCODE_VERSION} ${C_BLUE}\n > APPROVING CHAINCODE\n\n${C_RESET}"

for PEER in ${REPRESENTATIVE_PEERS_LIST}; do

  assumeRole ${PEER}

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode queryinstalled >& ${TEMP_TARGET}/package-id-${PEER}

  PACKAGE_ID=$(sed -n "/${CHAINCODE_LABEL}/{s/^Package ID: //; s/, Label:.*$//; p;}" ${TEMP_TARGET}/package-id-${PEER})

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode approveformyorg \
      -o ${ORDERER_ENDPOINT} \
      --tls --cafile ${ORDERER_TLS_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CHAINCODE_LABEL} \
      --version ${CHAINCODE_VERSION} \
      --package-id ${PACKAGE_ID} \
      --sequence ${CHAINCODE_VERSION} \
      ${COLLECTIONS_CONFIG_FLAG} \
      ${SIGNATURE_POLICY_FLAG}

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode checkcommitreadiness \
      --channelID ${CHANNEL_NAME} \
      --name ${CHAINCODE_LABEL} \
      --version ${CHAINCODE_VERSION} \
      --sequence ${CHAINCODE_VERSION} \
      --output json

done




############################################################## 
# COMMITING CHAINCODE
##############################################################

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_GRAY_ITALIC} ${CHAINCODE_LABEL}:${CHAINCODE_VERSION} ${C_BLUE}\n > COMMITTING CHAINCODE\n\n${C_RESET}"

assumeRole $(echo ${REPRESENTATIVE_PEERS_LIST} | awk '{print $1}')

while true; do

  sleep 10

  docker exec ${ENV} ${CLI_CONTAINER} \
    peer lifecycle chaincode commit \
      -o ${ORDERER_ENDPOINT} \
      --tls --cafile ${ORDERER_TLS_CA} \
      --channelID ${CHANNEL_NAME} \
      --name ${CHAINCODE_LABEL} \
      --version ${CHAINCODE_VERSION} \
      --sequence ${CHAINCODE_VERSION} \
      ${COLLECTIONS_CONFIG_FLAG} \
      ${SIGNATURE_POLICY_FLAG} \
      ${PEER_PARAMETERS}

  if [ $? -eq 0 ]; then
    break
  fi

done




############################################################## 
# TESTING CHAINCODE
##############################################################

printf "${C_BLUE_BOLD}\ndeploy-chaincode.sh:${C_GRAY_ITALIC} ${CHAINCODE_LABEL}:${CHAINCODE_VERSION} ${C_BLUE}\n > TESTING CHAINCODE\n\n${C_RESET}"
printf "${C_BLUE}(These tests will only work for the 'sacc' chaincode - available in the fabric-samples - as that was the chaincode used for the testing of this script. If you are deploying other chaincodes, copy the commands that will appear shortly in the terminal, and change the function names and arguments accordingly.)\n\n${C_RESET}"

sleep 60

assumeRole $(echo ${REPRESENTATIVE_PEERS_LIST} | awk '{print $1}')

echo -e "${C_BLUE}\nInvoking chaincode: writing key1 : value-${CHAINCODE_LABEL} ...${C_RESET}"
set -x
docker exec ${ENV} ${CLI_CONTAINER} \
  peer chaincode invoke \
    -o ${ORDERER_ENDPOINT} \
    --tls --cafile ${ORDERER_TLS_CA} \
    --channelID ${CHANNEL_NAME} \
    --name ${CHAINCODE_LABEL} \
    ${PEER_PARAMETERS} \
    -c '{"function":"set","args":["key1", "value-'${CHAINCODE_LABEL}'"]}' --waitForEvent
{ set +x; } 2>/dev/null

echo -e "${C_BLUE}\nQuerying chaincode: reading value of key1 ...${C_RESET}"
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
# CLEANING UP
##############################################################

echo y | rm -r ${TEMP_TARGET}