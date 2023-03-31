#!/bin/bash

set -o allexport && source .env && set +o allexport
export PATH=~/Desktop/fabric-samples/bin:$PATH




##############################################################
# FUNCTIONS - START
##############################################################

function assumeRole {

  PEER_NAME=$1
  ORG_NAME=$2
  ORG_URL=${ORG_NAME}.${PROJECT_URL}

  ENV=""
  ENV="${ENV} -e CORE_PEER_LOCALMSPID=${ORG_NAME^}MSP"
	ENV="${ENV} -e CORE_PEER_ADDRESS=${PEER_NAME}.${ORG_URL}:7051"
	ENV="${ENV} -e CORE_PEER_TLS_CERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt"
	ENV="${ENV} -e CORE_PEER_TLS_KEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key"
	ENV="${ENV} -e CORE_PEER_TLS_ROOTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt"
	ENV="${ENV} -e CORE_PEER_MSPCONFIGPATH=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/users/Admin@${ORG_URL}/msp"
	ENV="${ENV} -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/ca.crt"
	ENV="${ENV} -e CORE_PEER_TLS_CLIENTCERT_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.crt"
	ENV="${ENV} -e CORE_PEER_TLS_CLIENTKEY_FILE=${CLI_INTERNAL_CRYPTO_MATERIAL_DIR}/${ORG_URL}/peers/${PEER_NAME}.${ORG_URL}/tls/server.key"
}

##############################################################
# FUNCTIONS - END
##############################################################




############################################################## 
# INPUT VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-channel.sh: ${C_BLUE}\n > DEFINING INPUT VARIABLES\n\n${C_RESET}"

set -x
CHANNEL_NAME=$1 
{ set +x; } 2>/dev/null

ORGS_LIST=$({
  while (( "$#" )); do
    echo $2
    shift
  done
})

[[ -z ${CHANNEL_NAME} ]] && {
  >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} one or more mandatory arguments have not been provided!${C_RESET}"
  exit 1   
}




############################################################## 
# PROCESSING VARIABLES
##############################################################

printf "${C_BLUE_BOLD}\ncreate-channel.sh:${C_GRAY_ITALIC} ${CHANNEL_NAME} ${C_BLUE}\n > PROCESSING VARIABLES, DIRECTORIES, AND NECESSARY VERIFICATIONS\n\n${C_RESET}"

# In the .env file
PROJECT_URL=${ENV_PROJECT_URL}
CLI_CONTAINER=${ENV_CLI_CONTAINER}
ORDERER_ENDPOINT=${ENV_ORDERER_ENDPOINT}

SCRIPT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
FABRIC_TARGET=${SCRIPT}
FABRIC_EXPAND_TARGET=${FABRIC_TARGET}/expand

TEMP_TARGET=${SCRIPT}/${CHANNEL_NAME}_tmp
CONFIGTX_TARGET=${TEMP_TARGET}/configtx.yaml
CHANNEL_TX_TARGET=${TEMP_TARGET}/${CHANNEL_NAME}.tx

CLI_INTERNAL_CRYPTO_MATERIAL_DIR=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations

ORDERER_TLS_CA=$(docker exec ${CLI_CONTAINER} printenv ORDERER_TLS_CA)




############################################################## 
# PERFORMING VERIFICATIONS
#
# 1. Do the specified orgs exist?
# 2. Does any of the specified orgs already belong to an 
#    equally-named application channel?
##############################################################

for ORG_NAME in ${ORGS_LIST}; do
  docker ps | grep -i ${ORG_NAME} &> /dev/null || {
    >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} ${ORG_NAME} does not exist!${C_RESET}"
    exit 1
  }
done

for ORG_NAME in ${ORGS_LIST}; do
  assumeRole peer0 ${ORG_NAME}
  docker exec ${ENV} ${CLI_CONTAINER} peer channel list | grep ${CHANNEL_NAME} && {
    >&2 echo -e "${C_RED_BOLD}ERROR:${C_RED} ${ORG_NAME} is already a part of ${CHANNEL_NAME}!${C_RESET}"
    exit 1
  }
done




############################################################## 
# PROCESSING DIRECTORIES
##############################################################

echo y | rm -r ${TEMP_TARGET} &> /dev/null

mkdir -p ${TEMP_TARGET}
mkdir -p ${FABRIC_EXPAND_TARGET}

cd ${TEMP_TARGET}




############################################################## 
# CREATING CONFIG FILES - configtx.yaml
##############################################################

printf "${C_BLUE_BOLD}\ncreate-channel.sh:${C_GRAY_ITALIC} ${CHANNEL_NAME} ${C_BLUE}\n > CREATING configtx.yaml\n\n${C_RESET}"

cat << EOF > ${CONFIGTX_TARGET}
Organizations:
    - &OrdererOrg
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: ${FABRIC_TARGET}/crypto-config/ordererOrganizations/${PROJECT_URL}/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Writers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Admins:
                Type: Signature
                Rule: "OR('OrdererMSP.admin')"
        OrdererEndpoints:
            - orderer0.${PROJECT_URL}:7050
            - orderer1.${PROJECT_URL}:7050
            - orderer2.${PROJECT_URL}:7050
EOF

for ORG_NAME in ${ORGS_LIST}; do

  ORG_URL=${ORG_NAME}.${PROJECT_URL}
  ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_TARGET}/crypto-config/peerOrganizations/${ORG_URL}

  cat << EOF >> ${CONFIGTX_TARGET}        
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

done

cat << EOF >> ${CONFIGTX_TARGET}

Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
    Application: &ApplicationCapabilities
        V2_0: true

Application: &ApplicationDefaults
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
        Endorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
    Capabilities:
        <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
    OrdererType: etcdraft
    Addresses:
        - orderer0.${PROJECT_URL}:7050
        - orderer1.${PROJECT_URL}:7050
        - orderer2.${PROJECT_URL}:7050
    EtcdRaft:
        Consenters:
        - Host: orderer0.${PROJECT_URL}
          Port: 7050
          ClientTLSCert: crypto-config/ordererOrganizations/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/${PROJECT_URL}/orderers/orderer0.${PROJECT_URL}/tls/server.crt
        - Host: orderer1.${PROJECT_URL}
          Port: 7050
          ClientTLSCert: crypto-config/ordererOrganizations/${PROJECT_URL}/orderers/orderer1.${PROJECT_URL}/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/${PROJECT_URL}/orderers/orderer1.${PROJECT_URL}/tls/server.crt
        - Host: orderer2.${PROJECT_URL}
          Port: 7050
          ClientTLSCert: crypto-config/ordererOrganizations/${PROJECT_URL}/orderers/orderer2.${PROJECT_URL}/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/${PROJECT_URL}/orderers/orderer2.${PROJECT_URL}/tls/server.crt
    BatchTimeout: 2s
    BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        BlockValidation:
            Type: ImplicitMeta
            Rule: "ANY Writers"

Channel: &ChannelDefaults
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
    Capabilities:
        <<: *ChannelCapabilities

Profiles:
    OrgOrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:
                - *OrdererOrg
            Capabilities:
                <<: *OrdererCapabilities
        Consortiums:
            SampleConsortium:
                Organizations:
EOF

for ORG_NAME in ${ORGS_LIST}; do
  cat << EOF >> ${CONFIGTX_TARGET}
                    - *${ORG_NAME^}
EOF
done

cat << EOF >> ${CONFIGTX_TARGET}
    OrgChannel:
        Consortium: SampleConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:
EOF

for ORG_NAME in ${ORGS_LIST}; do
  cat << EOF >> ${CONFIGTX_TARGET}
                    - *${ORG_NAME^}
EOF
done

cat << EOF >> ${CONFIGTX_TARGET}
            Capabilities:
                <<: *ApplicationCapabilities
EOF

cp ${CONFIGTX_TARGET} ${FABRIC_EXPAND_TARGET}/configtx-${CHANNEL_NAME}.yaml




############################################################## 
# GENERATING APPLICATION CHANNEL CREATION TRANSACTION 
##############################################################

printf "${C_BLUE_BOLD}\ncreate-channel.sh:${C_GRAY_ITALIC} ${CHANNEL_NAME} ${C_BLUE}\n > GENERATING APPLICATION CHANNEL CREATION TRANSACTION\n\n${C_RESET}"

configtxgen -configPath ${TEMP_TARGET} -profile OrgChannel -outputCreateChannelTx ${CHANNEL_TX_TARGET} -channelID ${CHANNEL_NAME}

cp ${CHANNEL_TX_TARGET} ${FABRIC_TARGET}/config/${CHANNEL_NAME}.tx




############################################################## 
# CREATING APPLICATION CHANNEL 
##############################################################

printf "${C_BLUE_BOLD}\ncreate-channel.sh:${C_GRAY_ITALIC} ${CHANNEL_NAME} ${C_BLUE}\n > CREATING APPLICATION CHANNEL\n\n${C_RESET}"

ORG_NAME=$(echo ${ORGS_LIST} | awk '{print $1;}')

assumeRole peer0 ${ORG_NAME}

docker exec ${ENV} ${CLI_CONTAINER} \
  peer channel create \
    -o ${ORDERER_ENDPOINT} \
    -c ${CHANNEL_NAME} \
    -f /etc/hyperledger/configtx/${CHANNEL_NAME}.tx \
    --tls --cafile ${ORDERER_TLS_CA}




############################################################## 
# JOINING PEERS TO APPLICATION CHANNEL 
##############################################################

printf "${C_BLUE_BOLD}\ncreate-channel.sh:${C_GRAY_ITALIC} ${CHANNEL_NAME} ${C_BLUE}\n > JOINING PEERS TO APPLICATION CHANNEL\n\n${C_RESET}"

for ORG_NAME in ${ORGS_LIST}; do

	PEERS_LIST=$(docker ps --format {{.Names}} | grep ^peer | grep ${ORG_NAME} | sort | tr "." " " | awk '{print $1}')

	for PEER_NAME in ${PEERS_LIST}; do

    echo -e "${C_BLUE}\nJoining ${PEER_NAME}.${ORG_NAME} ...${C_RESET}"

    assumeRole ${PEER_NAME} ${ORG_NAME}
		
    docker exec ${ENV} ${CLI_CONTAINER} \
      peer channel fetch oldest ${CHANNEL_NAME}.block \
        -o ${ORDERER_ENDPOINT} \
        -c ${CHANNEL_NAME} \
        --tls --cafile ${ORDERER_TLS_CA}

    docker exec ${ENV} ${CLI_CONTAINER} \
      peer channel join \
        -b ${CHANNEL_NAME}.block

	done
done




############################################################## 
# CLEANING UP
##############################################################

echo y | rm -r ${TEMP_TARGET}