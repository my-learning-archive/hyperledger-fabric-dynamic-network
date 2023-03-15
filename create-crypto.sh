#!/bin/bash

C_RESET='\033[0m'
C_BLUE='\033[0;34m'




################################ 
# PROCESSING ARGS 
################################

orgName=$1
caPort=$2
adminUsername=$3
adminPassword=$4




################################ 
# PROCESSING VARIABLES 
################################

workDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

orgURL="$orgName.example.com"
caName="ca.example.com"

orgFolder="$workDir/crypto-config/peerOrganizations/$orgURL"
caTlsCert="$orgFolder/ca/ca.$orgName.example.com-cert.pem"

orgMSP=$orgFolder/msp

peersFolder=$orgFolder/peers
usersFolder=$orgFolder/users




################################ 
# ENROLLING CA ADMIN 
################################

echo -e "${C_BLUE}\nEnrolling CA Admin${C_RESET}"
mkdir -p $orgFolder/

export FABRIC_CA_CLIENT_HOME=$orgFolder/

fabric-ca-client enroll \
  -u https://$adminUsername:$adminPassword@localhost:$caPort \
  --caname $caName \
  --tls.certfiles $caTlsCert
[[ ! $? -eq 0 ]] && {
  >&2 echo "YOU ARE NOT AUTHORIZED TO OPERATE ${ORG_NAME}!"
  exit 1
}




################################ 
# FUNCTION: Creating Org Crypto
################################

function createOrg(){

  OUFile="NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/localhost-$caPort-ca-example-com.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/localhost-$caPort-ca-example-com.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/localhost-$caPort-ca-example-com.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/localhost-$caPort-ca-example-com.pem
      OrganizationalUnitIdentifier: orderer"

  echo "$OUFile" >$orgMSP/config.yaml

  createUser "client" "User1" "user1" "user1pw"
  createUser "admin" "Admin" "${orgName}admin" "${orgName}adminpw"
  createPeer "peer0" "peer0" "peer0pw"
  #createCCP $peerPort
}




################################ 
# FUNCTION: Creating User Crypto
################################

function createUser(){

  userType=$1
  userName=$2
  userUsername=$3
  userPassword=$4
  
  if [[ $userType == "client" ]]; then
    str1="Registering ${userName}"
    str2="Generating the ${userName} msp"
    str3="Generating the ${userName} tls"
  else
    str1="Registering the org admin"
    str2="Generating the org admin msp"
    str3="Generating the org admin tls"
  fi
  
  echo -e "${C_BLUE}\n${str1}${C_RESET}"
  set -x
  fabric-ca-client register \
    --caname $caName \
    --id.name $userUsername \
    --id.secret $userPassword \
    --id.type $userType \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\n${str2}${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://$userUsername:$userPassword@localhost:$caPort \
    --caname $caName \
    -M $usersFolder/$userName@$orgURL/msp \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\n${str3}${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://$userUsername:$userPassword@localhost:$caPort \
    --caname $caName \
    -M $usersFolder/$userName@$orgURL/tls \
    --enrollment.profile tls \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null  

  cp $orgMSP/config.yaml $usersFolder/$userName@$orgURL/msp/config.yaml
}




################################ 
# FUNCTION: Creating Peer Crypto
################################

function createPeer(){

  peerName=$1
  peerUsername=$2
  peerPassword=$3
    
  echo -e "${C_BLUE}\nRegistering ${peerName}${C_RESET}"
  set -x
  fabric-ca-client register \
    --caname $caName \
    --id.name $peerUsername \
    --id.secret $peerPassword \
    --id.type peer \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\nGenerating ${peerName} msp${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://$peerUsername:$peerPassword@localhost:$caPort \
    --caname $caName \
    -M $peersFolder/$peerName.$orgURL/msp \
    --csr.hosts $peerName.$orgURL \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  cp $orgMSP/config.yaml $peersFolder/$peerName.$orgURL/msp/config.yaml

  echo -e "${C_BLUE}\nGenerating ${peerName} tls${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://$peerUsername:$peerPassword@localhost:$caPort \
    --caname $caName \
    -M $peersFolder/$peerName.$orgURL/tls \
    --enrollment.profile tls \
    --csr.hosts $peerName.$orgURL \
    --csr.hosts localhost \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  cp $peersFolder/$peerName.$orgURL/tls/tlscacerts/* $peersFolder/$peerName.$orgURL/tls/ca.crt
  cp $peersFolder/$peerName.$orgURL/tls/signcerts/* $peersFolder/$peerName.$orgURL/tls/server.crt
  cp $peersFolder/$peerName.$orgURL/tls/keystore/* $peersFolder/$peerName.$orgURL/tls/server.key

  mkdir -p $orgMSP/tlscacerts
  cp $peersFolder/$peerName.$orgURL/tls/tlscacerts/* $orgMSP/tlscacerts/ca.crt

  mkdir -p $orgFolder/tlsca
  cp $peersFolder/$peerName.$orgURL/tls/tlscacerts/* $orgFolder/tlsca/tlsca.$orgURL-cert.pem
}




################################ 
# OTHER FUNCTIONS
################################

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

  echo -e "${C_BLUE}\nGenerating ccp for ${orgName}${C_RESET}"
  ORG=$(echo $orgName | sed -e 's/org//g')
	P0PORT=$1
	CAPORT=$caPort
	PEERPEM=organizations/peerOrganizations/$orgName.example.com/tlsca/tlsca.$orgName.example.com-cert.pem
	CAPEM=organizations/peerOrganizations/$orgName.example.com/ca/ca.$orgName.example.com-cert.pem

	echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/$orgName.example.com/connection-$orgName.json
	echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/$orgName.example.com/connection-$orgName.yaml
}






