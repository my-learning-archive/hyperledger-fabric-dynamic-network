#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# INPUT VARIABLES 
##############################################################

ORG_NAME=$1
CA_7054_PORT=$2
ADMIN_USERNAME=$3
ADMIN_PASSWORD=$4




############################################################## 
# PROCESSING VARIABLES 
##############################################################

PROJECT_URL=${COMPOSE_PROJECT_URL} # In the .env file

WORK_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

[[ ${ORG_NAME} =~ ^org[1-99] ]] && {
  ORG_URL="${ORG_NAME}.${PROJECT_URL}"
  CA_NAME="ca.${PROJECT_URL}"
  ENTITY_TYPE="peer"
  ORG_CRYPTO_MATERIAL_TARGET="${WORK_DIR}/crypto-config/peerOrganizations/${ORG_URL}"
  CA_TLS_CERTIFICATE="${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_URL}-cert.pem"
  ORG_MSP="${ORG_CRYPTO_MATERIAL_TARGET}/msp"
  ENTITIES_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/peers"
  USERS_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/users"
}

[[ ${ORG_NAME} == orderer ]] && {
  ORG_URL="${PROJECT_URL}"
  CA_NAME="ca.${PROJECT_URL}"
  ENTITY_TYPE="orderer"
  ORG_CRYPTO_MATERIAL_TARGET="${WORK_DIR}/crypto-config/ordererOrganizations/${ORG_URL}"
  CA_TLS_CERTIFICATE="${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_URL}-cert.pem"
  ORG_MSP="${ORG_CRYPTO_MATERIAL_TARGET}/msp"
  ENTITIES_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/orderers"
  USERS_CRYPTO_MATERIAL_TARGET="${ORG_CRYPTO_MATERIAL_TARGET}/users"
}




############################################################## 
# ENROLLING CA ADMIN 
##############################################################

echo -e "${C_BLUE}\nEnrolling CA Admin${C_RESET}"
mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/

export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}/

fabric-ca-client enroll \
  -u https://${ADMIN_USERNAME}:${ADMIN_PASSWORD}@localhost:${CA_7054_PORT} \
  --caname ${CA_NAME} \
  --tls.certfiles ${CA_TLS_CERTIFICATE}
[[ ! $? -eq 0 ]] && {
  >&2 echo "YOU ARE NOT AUTHORIZED TO OPERATE ${ORG_NAME}!"
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
      Certificate: cacerts/localhost-${CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/localhost-${CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/localhost-${CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/localhost-${CA_7054_PORT}-ca-${PROJECT_URL_DASHED}.pem
      OrganizationalUnitIdentifier: orderer"

  echo "${OU_FILE}" >${ORG_MSP}/config.yaml

  [[ ${ORG_NAME} =~ ^org[1-99] ]] && {
    createUser "client" "User1" "user1" "user1pw"
    createUser "admin" "Admin" "${ORG_NAME}admin" "${ORG_NAME}adminpw"
    createEntity "peer0" "peer0" "peer0pw"
    return
  }

  [[ ${ORG_NAME} == orderer ]] && {
    createUser "admin" "Admin" "${ORG_NAME}admin" "${ORG_NAME}adminpw"
    createEntity "orderer0" "orderer0" "orderer0pw"
    createEntity "orderer1" "orderer1" "orderer1pw"
    createEntity "orderer2" "orderer2" "orderer2pw"
    return
  }
}




############################################################## 
# FUNCTION: Creating User Crypto
##############################################################

function createUser(){

  USER_TYPE=$1
  USER_NAME=$2
  USER_USERNAME=$3
  USER_PASSWORD=$4
  
  if [[ $userType == "client" ]]; then
    str1="Registering ${USER_NAME}"
    str2="Generating the ${USER_NAME} msp"
    str3="Generating the ${USER_NAME} tls"
  else
    str1="Registering the org admin"
    str2="Generating the org admin msp"
    str3="Generating the org admin tls"
  fi
  
  echo -e "${C_BLUE}\n${str1}${C_RESET}"
  set -x
  fabric-ca-client register \
    --caname ${CA_NAME} \
    --id.name ${USER_USERNAME} \
    --id.secret ${USER_PASSWORD} \
    --id.type ${USER_TYPE} \
    --tls.certfiles ${CA_TLS_CERTIFICATE}
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\n${str2}${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://${USER_USERNAME}:${USER_PASSWORD}@localhost:${CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/msp \
    --tls.certfiles ${CA_TLS_CERTIFICATE}
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\n${str3}${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://${USER_USERNAME}:${USER_PASSWORD}@localhost:${CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/tls \
    --enrollment.profile tls \
    --tls.certfiles ${CA_TLS_CERTIFICATE}
  { set +x; } 2>/dev/null  

  cp ${ORG_MSP}/config.yaml ${USERS_CRYPTO_MATERIAL_TARGET}/${USER_NAME}@${ORG_URL}/msp/config.yaml
}




############################################################## 
# FUNCTION: Creating Entity Crypto
##############################################################

function createEntity(){

  ENTITY_NAME=$1 # peer or orderer
  ENTITY_USERNAME=$2
  ENTITY_PASSWORD=$3
    
  echo -e "${C_BLUE}\nRegistering ${ENTITY_NAME}${C_RESET}"
  set -x
  fabric-ca-client register \
    --caname ${CA_NAME} \
    --id.name ${ENTITY_USERNAME} \
    --id.secret ${ENTITY_PASSWORD} \
    --id.type ${ENTITY_TYPE} \
    --tls.certfiles ${CA_TLS_CERTIFICATE}
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\nGenerating ${ENTITY_NAME} msp${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://${ENTITY_USERNAME}:${ENTITY_PASSWORD}@localhost:${CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/msp \
    --csr.hosts ${ENTITY_NAME}.${ORG_URL} \
    --tls.certfiles ${CA_TLS_CERTIFICATE}
  { set +x; } 2>/dev/null

  cp ${ORG_MSP}/config.yaml ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/msp/config.yaml

  echo -e "${C_BLUE}\nGenerating ${ENTITY_NAME} tls${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://${ENTITY_USERNAME}:${ENTITY_PASSWORD}@localhost:${CA_7054_PORT} \
    --caname ${CA_NAME} \
    -M ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls \
    --enrollment.profile tls \
    --csr.hosts ${ENTITY_NAME}.${ORG_URL} \
    --csr.hosts localhost \
    --tls.certfiles ${CA_TLS_CERTIFICATE}
  { set +x; } 2>/dev/null

  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/tlscacerts/* ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/ca.crt
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/signcerts/* ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/server.crt
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/keystore/* ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/server.key

  mkdir -p ${ORG_MSP}/tlscacerts
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/tlscacerts/* ${ORG_MSP}/tlscacerts/ca.crt

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca
  cp ${ENTITIES_CRYPTO_MATERIAL_TARGET}/${ENTITY_NAME}.${ORG_URL}/tls/tlscacerts/* ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/tlsca.${ORG_URL}-cert.pem
}




############################################################## 
# OTHER FUNCTIONS - START
##############################################################

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}


function json_ccp {
  local PP=$(one_line_pem $4)
  local CP=$(one_line_pem $5)
  sed -e "s/\${ORG}/$1/" \
      -e "s/\${P0PORT}/$2/" \
      -e "s/\${CAPORT}/$3/" \
      -e "s#\${PEERPEM}#$PP#" \
      -e "s#\${CAPEM}#$CP#" \
      organizations/ccp-template.json
}


function yaml_ccp {
  local PP=$(one_line_pem $4)
  local CP=$(one_line_pem $5)
  sed -e "s/\${ORG}/$1/" \
      -e "s/\${P0PORT}/$2/" \
      -e "s/\${CAPORT}/$3/" \
      -e "s#\${PEERPEM}#$PP#" \
      -e "s#\${CAPEM}#$CP#" \
      organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}


function createCCP(){

  echo -e "${C_BLUE}\nGenerating ccp for ${ORG_NAME}${C_RESET}"
  ORG=$(echo ${ORG_NAME} | sed -e 's/org//g')
	P0PORT=$1
	CAPORT=${CA_7054_PORT}
	PEERPEM=organizations/peerOrganizations/${ORG_URL}/tlsca/tlsca.${ORG_URL}-cert.pem
	CAPEM=organizations/peerOrganizations/${ORG_URL}/ca/ca.${ORG_URL}-cert.pem

	echo "$(json_ccp $ORG $P0PORT ${CA_7054_PORT} $PEERPEM $CAPEM)" > organizations/peerOrganizations/${ORG_URL}/connection-${ORG_NAME}.json
	echo "$(yaml_ccp $ORG $P0PORT ${CA_7054_PORT} $PEERPEM $CAPEM)" > organizations/peerOrganizations/${ORG_URL}/connection-${ORG_NAME}.yaml
}

############################################################## 
# OTHER FUNCTIONS - END
##############################################################





