#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# INPUT VARIABLES 
##############################################################

ORG_NAME=$1
ORG_CA_7054_PORT=$2
ORG_CA_ADMIN_USERNAME=$3
ORG_CA_ADMIN_PASSWORD=$4




############################################################## 
# PROCESSING VARIABLES 
##############################################################

# In the .env file
PROJECT_URL=${ENV_PROJECT_URL}
TLS_CA_7054_PORT=${ENV_TLS_CA_7054_PORT}
TLS_CA_ADMIN_USERNAME=${ENV_TLS_CA_ADMIN_USERNAME}
TLS_CA_ADMIN_PASSWORD=${ENV_TLS_CA_ADMIN_PASSWORD}

FABRIC_TARGET=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

TLS_CA_REMOTE_TLS_CERTIFICATE="${FABRIC_TARGET}/crypto-config/tlsOrganizations/${PROJECT_URL}/tlsca/tls.ca.${PROJECT_URL}-cert.pem"

[[ ${ORG_NAME} =~ ^org[1-99] ]] && {
  ORG_URL="${ORG_NAME}.${PROJECT_URL}"
  CA_NAME="ca.${PROJECT_URL}"
  ENTITY_TYPE="peer"
  ORG_CRYPTO_MATERIAL_TARGET="${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}"
  ORG_CA_TLS_CERTIFICATE="${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_URL}-cert.pem"
  TLS_CA_TLS_CERTIFICATE="${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/tlsca.${ORG_URL}-cert.pem"
  ORG_MSP="${ORG_CRYPTO_MATERIAL_TARGET}/msp"
  ENTITIES_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/peers"
  USERS_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/users"
}

[[ ${ORG_NAME} == orderer ]] && {
  ORG_URL="${PROJECT_URL}"
  CA_NAME="ca.${PROJECT_URL}"
  ENTITY_TYPE="orderer"
  ORG_CRYPTO_MATERIAL_TARGET="${FABRIC_TARGET}/crypto-config/ordererOrganizations/${ORG_URL}"
  ORG_CA_TLS_CERTIFICATE="${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_URL}-cert.pem"
  TLS_CA_TLS_CERTIFICATE="${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/tlsca.${ORG_URL}-cert.pem"
  ORG_MSP="${ORG_CRYPTO_MATERIAL_TARGET}/msp"
  ENTITIES_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/orderers"
  USERS_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/users"
}




############################################################## 
# PROCESSING DIRECTORIES 
##############################################################

mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/
cp ${TLS_CA_REMOTE_TLS_CERTIFICATE} ${TLS_CA_TLS_CERTIFICATE}




############################################################## 
# ENROLLING CA ADMIN 
##############################################################

echo -e "${C_BLUE}\nEnrolling organizational CA admin ...${C_RESET}"

export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/

fabric-ca-client enroll \
  -u https://${ORG_CA_ADMIN_USERNAME}:${ORG_CA_ADMIN_PASSWORD}@localhost:${ORG_CA_7054_PORT} \
  --caname ${CA_NAME} \
  --tls.certfiles ${ORG_CA_TLS_CERTIFICATE}
[[ ! $? -eq 0 ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} you are not authorized to operate ${ORG_NAME}'s CA - incorrect credentials!${C_RESET}"
  exit 1
}

echo -e "${C_BLUE}\nEnrolling TLS CA admin ...${C_RESET}"

export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/tlsca

fabric-ca-client enroll \
  -u https://${TLS_CA_ADMIN_USERNAME}:${TLS_CA_ADMIN_PASSWORD}@localhost:${TLS_CA_7054_PORT} \
  --caname ${CA_NAME} \
  --tls.certfiles ${TLS_CA_TLS_CERTIFICATE}
[[ ! $? -eq 0 ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} you are not authorized to operate the TLS CA - incorrect credentials!${C_RESET}"
  exit 1
}




############################################################## 
# FUNCTION: Creating Org Crypto
##############################################################

function createOrg(){

  PROJECT_URL_DASHED=$(echo ${PROJECT_URL} | tr "." "-")

  OU_FILE="NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/localhost-${ORG_CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/localhost-${ORG_CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/localhost-${ORG_CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/localhost-${ORG_CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: orderer"

  echo "${OU_FILE}" >${ORG_MSP}/config.yaml

  createUser "admin" "Admin" "${ORG_NAME}admin" "${ORG_NAME}adminpw"
  createUserTLS "admin" "Admin" "${ORG_NAME}admin" "${ORG_NAME}adminpw"
}




############################################################## 
# FUNCTION: Creating User Identity Crypto
##############################################################

function createUser(){

  export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/

  USER_TYPE=$1
  USER_NAME=$2
  USER_USERNAME=$3
  USER_PASSWORD=$4
  USER_ROLE=${5:-"NA"}

  [[ ${USER_ROLE} == "NA" ]] || {
    USER_ROLE_FLAG="--id.attrs role=${USER_ROLE}:ecert"
  }
  
  echo -e "${C_BLUE}\nRegistering to organizational CA: ${USER_NAME}@${ORG_URL} ...${C_RESET}"

  fabric-ca-client register \
    --caname ${CA_NAME} \
    --id.name ${USER_USERNAME} \
    --id.secret ${USER_PASSWORD} \
    --id.type ${USER_TYPE} ${USER_ROLE_FLAG} \
    --tls.certfiles ${ORG_CA_TLS_CERTIFICATE}

  echo -e "${C_BLUE}\nGenerating MSP: ${USER_NAME}@${ORG_URL} ...${C_RESET}"

  fabric-ca-client enroll \
    -u https://${USER_USERNAME}:${USER_PASSWORD}@localhost:${ORG_CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/msp \
    --tls.certfiles ${ORG_CA_TLS_CERTIFICATE}

  cp ${ORG_MSP}/config.yaml ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/msp/config.yaml
}




############################################################## 
# FUNCTION: Creating User TLS Crypto
##############################################################

function createUserTLS(){

  export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/tlsca

  USER_TYPE=$1
  USER_NAME=$2
  USER_USERNAME=$3
  USER_PASSWORD=$4
  USER_ROLE=${5:-"NA"}

  [[ ${USER_ROLE} == "NA" ]] || {
    USER_ROLE_FLAG="--id.attrs role=${USER_ROLE}:ecert"
  }

  echo -e "${C_BLUE}\nRegistering to TLS CA: ${USER_NAME}@${ORG_URL} ...${C_RESET}"

  fabric-ca-client register \
    --caname ${CA_NAME} \
    --id.name ${USER_USERNAME} \
    --id.secret ${USER_PASSWORD} \
    --id.type ${USER_TYPE} ${USER_ROLE_FLAG} \
    --tls.certfiles ${TLS_CA_TLS_CERTIFICATE}

  echo -e "${C_BLUE}\nGenerating TLS: ${USER_NAME}@${ORG_URL} ...${C_RESET}"

  fabric-ca-client enroll \
    -u https://${USER_USERNAME}:${USER_PASSWORD}@localhost:${TLS_CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls \
    --enrollment.profile tls \
    --tls.certfiles ${TLS_CA_TLS_CERTIFICATE}

  cp ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/tlscacerts/* ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/ca.crt
  cp ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/signcerts/* ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/client.crt
  cp ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/keystore/* ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/client.key

  mkdir -p ${ORG_MSP}/tlscacerts
  cp ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/tlscacerts/* ${ORG_MSP}/tlscacerts/ca.crt

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca
  cp ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls/tlscacerts/* ${TLS_CA_TLS_CERTIFICATE}
}




############################################################## 
# FUNCTION: Creating Entity Identity Crypto
##############################################################

function createEntity(){

  export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/

  ENTITY_NAME=$1 # peer or orderer
  ENTITY_USERNAME=$2
  ENTITY_PASSWORD=$3
    
  echo -e "${C_BLUE}\nRegistering to organizational CA: ${ENTITY_NAME}.${ORG_URL} ...${C_RESET}"

  fabric-ca-client register \
    --caname ${CA_NAME} \
    --id.name ${ENTITY_USERNAME} \
    --id.secret ${ENTITY_PASSWORD} \
    --id.type ${ENTITY_TYPE} \
    --tls.certfiles ${ORG_CA_TLS_CERTIFICATE}

  echo -e "${C_BLUE}\nGenerating MSP: ${ENTITY_NAME}.${ORG_URL} ...${C_RESET}"

  fabric-ca-client enroll \
    -u https://${ENTITY_USERNAME}:${ENTITY_PASSWORD}@localhost:${ORG_CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/msp \
    --csr.hosts ${ENTITY_NAME}.${ORG_URL} \
    --tls.certfiles ${ORG_CA_TLS_CERTIFICATE}

  cp ${ORG_MSP}/config.yaml ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/msp/config.yaml
}




############################################################## 
# FUNCTION: Creating Entity TLS Crypto
##############################################################

function createEntityTLS(){

  export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/tlsca

  ENTITY_NAME=$1 # peer or orderer
  ENTITY_USERNAME=$2
  ENTITY_PASSWORD=$3
    
  echo -e "${C_BLUE}\nRegistering to TLS CA: ${ENTITY_NAME}.${ORG_URL} ...${C_RESET}"

  fabric-ca-client register \
    --caname ${CA_NAME} \
    --id.name ${ENTITY_USERNAME} \
    --id.secret ${ENTITY_PASSWORD} \
    --id.type ${ENTITY_TYPE} \
    --tls.certfiles ${TLS_CA_TLS_CERTIFICATE}

  echo -e "${C_BLUE}\nGenerating TLS: ${ENTITY_NAME}.${ORG_URL} ...${C_RESET}"

  fabric-ca-client enroll \
    -u https://${ENTITY_USERNAME}:${ENTITY_PASSWORD}@localhost:${TLS_CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls \
    --enrollment.profile tls \
    --csr.hosts ${ENTITY_NAME}.${ORG_URL} \
    --csr.hosts localhost \
    --tls.certfiles ${TLS_CA_TLS_CERTIFICATE}

  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/tlscacerts/* ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/ca.crt
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/signcerts/* ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/server.crt
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/keystore/* ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/server.key

  mkdir -p ${ORG_MSP}/tlscacerts
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/tlscacerts/* ${ORG_MSP}/tlscacerts/ca.crt

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/tlscacerts/* ${TLS_CA_TLS_CERTIFICATE}
}





