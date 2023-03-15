#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
# Adapted by duartegithub

# Set env vars
export PATH=~/Desktop/fabric-samples/bin:$PATH
export FABRIC_CFG_PATH=${PWD}
export CHANNEL_NAME=allarewelcome

# Remove previous crypto material and config transactions
mkdir -p config
rm -fr config/*
rm -fr crypto-config/*

# Generate crypto material - orgs
for ORG in "org1" "org2"; do

  ORG_NAME=${ORG}
  printf "${C_BLUE}\n>>> GENERATING CRYPTO-MATERIALS FOR ${ORG_NAME}\n${C_RESET}"

  ORG_CRYPTO_MATERIAL_TARGET=${FABRIC_CFG_PATH}/crypto-config/peerOrganizations/${ORG_NAME}.example.com
  NODEOUS_TARGET=${ORG_CRYPTO_MATERIAL_TARGET}/msp/config.yaml

  echo y | rm -r ${FABRIC_CA_CLIENT_DIR}

  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/ca/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/tlscacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/msp/cacerts/
  mkdir -p ${ORG_CRYPTO_MATERIAL_TARGET}/tlsca/

  CA_7054_PORT=$(yq '.services."ca.'${ORG_NAME}'.example.com".ports' ${FABRIC_CFG_PATH}/docker-compose.yml | cut -c 4- | sed 's/[:].*//')

  ADMIN_USERNAME=admin
  ADMIN_PASSWORD=adminpw

  docker compose -f ${FABRIC_CFG_PATH}/docker-compose.yml up -d ca.${ORG_NAME}.example.com

  sleep 10

  . create-crypto.sh ${ORG_NAME} ${CA_7054_PORT} ${ADMIN_USERNAME} ${ADMIN_PASSWORD}
  createOrg
  createPeer peer1 peer1 peer1pw

done

# Generate crypto material (orderer)
cryptogen generate --config=./crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

# Generate genesis block for orderer
configtxgen -profile TwoOrgOrdererGenesis -channelID system-channel -outputBlock ./config/genesis.block
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# Generate channel creation transaction
configtxgen -profile TwoOrgChannel -outputCreateChannelTx ./config/$CHANNEL_NAME.tx -channelID $CHANNEL_NAME
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel creation transaction..."
  exit 1
fi

# Generate anchor peer transaction for org1
configtxgen -profile TwoOrgChannel -outputAnchorPeersUpdate ./config/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org1MSP..."
  exit 1
fi

# Generate anchor peer transaction for org2
configtxgen -profile TwoOrgChannel -outputAnchorPeersUpdate ./config/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org2MSP..."
  exit 1
fi