#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




############################################################## 
# INPUT VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-user.sh:${C_BLUE}\n > DEFINING INPUT VARIABLE\n\n${C_RESET}"

set -x
ORG_NAME=$1
USER_USERNAME=$2
USER_PASSWORD=$3
ORG_CA_ADMIN_USERNAME=$4
ORG_CA_ADMIN_PASSWORD=$5
USER_ROLE=${6:-"NA"}
{ set +x; } 2>/dev/null

[[ -z ${ORG_NAME} || -z ${USER_USERNAME} || -z ${USER_PASSWORD} || -z ${ORG_CA_ADMIN_USERNAME} || -z ${ORG_CA_ADMIN_PASSWORD} || -z ${USER_ROLE} ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} one or more mandatory arguments have not been provided!${C_RESET}"
  exit 1   
}




############################################################## 
# PROCESSING VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-user.sh:${C_GRAY_ITALIC} ${USER_USERNAME}@${ORG_NAME} ${C_BLUE}\n > PROCESSING VARIABLES, DIRECTORIES, AND NECESSARY VERIFICATIONS\n\n${C_RESET}"

# In the .env file
PROJECT_URL=${ENV_PROJECT_URL}

ORG_URL=${ORG_NAME}.${PROJECT_URL}

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}
ORG_CA_TLS_CERTIFICATE=${ORG_CRYPTO_MATERIAL_TARGET}/ca/ca.${ORG_URL}-cert.pem

ORG_CA_7054_PORT=$(docker inspect ca.${ORG_URL} | grep HostPort | head -n 1 | awk '{print $2}' | tr -d '"')




############################################################## 
# PERFORMING VERIFICATIONS
#
# 1. Does the specified org exist?
# 2. Are the provided admin credentials authorized?
##############################################################

[[ ${ORG_CA_7054_PORT} == '' ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} could not obtain the port of the ca of ${ORG_NAME} - check if ${ORG_NAME} exists and if its CA is running!${C_RESET}"
  exit 1
}

cd ${FABRIC_TARGET}
. create-crypto.sh ${ORG_NAME} ${ORG_CA_7054_PORT} ${ORG_CA_ADMIN_USERNAME} ${ORG_CA_ADMIN_PASSWORD}




############################################################## 
# GENERATING CERTIFICATES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-user.sh:${C_GRAY_ITALIC} ${USER_USERNAME}@${ORG_NAME} ${C_BLUE}\n > REGISTERING USER AND GENERATING CRYPTO-MATERIALS\n\n${C_RESET}"

createUser "client" "${USER_USERNAME^}" "${USER_USERNAME}" "${USER_PASSWORD}" "${USER_ROLE}"
createUserTLS "client" "${USER_USERNAME^}" "${USER_USERNAME}" "${USER_PASSWORD}" "${USER_ROLE}"




############################################################## 
# LISTING USERS
##############################################################

printf "${C_BLUE_BOLD}\ncreate-user.sh:${C_GRAY_ITALIC} ${USER_USERNAME}@${ORG_NAME} ${C_BLUE}\n > TESTING: REQUESTING IDENTITY DATA FROM ORGANIZATIONAL CA\n\n${C_RESET}"

export FABRIC_CA_CLIENT_HOME=${ORG_CRYPTO_MATERIAL_TARGET}

fabric-ca-client identity list --caname ca.${PROJECT_URL} --tls.certfiles ${ORG_CA_TLS_CERTIFICATE} | grep ${USER_USERNAME}