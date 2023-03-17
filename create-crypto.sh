#!/bin/bash

set -o allexport && source .env && set +o allexport




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

[[ $orgName =~ ^org[1-99] ]] && {
  orgURL="$orgName.example.com"
  caName="ca.example.com"
  entityType="peer"
  orgFolder="$workDir/crypto-config/peerOrganizations/$orgURL"
  caTlsCert="$orgFolder/ca/ca.$orgName.example.com-cert.pem"
  orgMSP=$orgFolder/msp
  entitiesFolder=$orgFolder/peers
  usersFolder=$orgFolder/users
}

[[ $orgName == orderer ]] && {
  orgURL="example.com"
  caName="ca.example.com"
  entityType="orderer"
  orgFolder="$workDir/crypto-config/ordererOrganizations/$orgURL"
  caTlsCert="$orgFolder/ca/ca.example.com-cert.pem"
  orgMSP=$orgFolder/msp
  entitiesFolder=$orgFolder/orderers
  usersFolder=$orgFolder/users
}




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

  [[ $orgName =~ ^org[1-99] ]] && {
    createUser "client" "User1" "user1" "user1pw"
    createUser "admin" "Admin" "${orgName}admin" "${orgName}adminpw"
    createEntity "peer0" "peer0" "peer0pw"
    return
  }

  [[ $orgName == orderer ]] && {
    createUser "admin" "Admin" "${orgName}admin" "${orgName}adminpw"
    createEntity "orderer" "orderer" "ordererpw"
    createEntity "orderer2" "orderer2" "orderer2pw"
    createEntity "orderer3" "orderer3" "orderer3pw"
    return
  }
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
# FUNCTION: Creating Entity Crypto
################################

function createEntity(){

  entityName=$1 # peer or orderer
  entityUsername=$2
  entityPassword=$3
    
  echo -e "${C_BLUE}\nRegistering ${entityName}${C_RESET}"
  set -x
  fabric-ca-client register \
    --caname $caName \
    --id.name $entityUsername \
    --id.secret $entityPassword \
    --id.type $entityType \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  echo -e "${C_BLUE}\nGenerating ${entityName} msp${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://$entityUsername:$entityPassword@localhost:$caPort \
    --caname $caName \
    -M $entitiesFolder/$entityName.$orgURL/msp \
    --csr.hosts $entityName.$orgURL \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  cp $orgMSP/config.yaml $entitiesFolder/$entityName.$orgURL/msp/config.yaml

  echo -e "${C_BLUE}\nGenerating ${entityName} tls${C_RESET}"
  set -x
  fabric-ca-client enroll \
    -u https://$entityUsername:$entityPassword@localhost:$caPort \
    --caname $caName \
    -M $entitiesFolder/$entityName.$orgURL/tls \
    --enrollment.profile tls \
    --csr.hosts $entityName.$orgURL \
    --csr.hosts localhost \
    --tls.certfiles $caTlsCert
  { set +x; } 2>/dev/null

  cp $entitiesFolder/$entityName.$orgURL/tls/tlscacerts/* $entitiesFolder/$entityName.$orgURL/tls/ca.crt
  cp $entitiesFolder/$entityName.$orgURL/tls/signcerts/* $entitiesFolder/$entityName.$orgURL/tls/server.crt
  cp $entitiesFolder/$entityName.$orgURL/tls/keystore/* $entitiesFolder/$entityName.$orgURL/tls/server.key

  mkdir -p $orgMSP/tlscacerts
  cp $entitiesFolder/$entityName.$orgURL/tls/tlscacerts/* $orgMSP/tlscacerts/ca.crt

  mkdir -p $orgFolder/tlsca
  cp $entitiesFolder/$entityName.$orgURL/tls/tlscacerts/* $orgFolder/tlsca/tlsca.$orgURL-cert.pem
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






