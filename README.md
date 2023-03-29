# Adding nodes to Hyperledger Fabric networks

This was a small project to learn how to add Orgs and Peers to a local Hyperledger Fabric network. This project is based on the finalized laboratoriies of the TLF HLF for Administrators Course

**Requirements:**
- Docker 
- Docker Compose v2
- fabric-samples (in the `~/Desktop`)

---
**Before start:**

Install the fabric-samples in the `~/Desktop` folder:

> `cd ~/Desktop` \
> `curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.2.1 1.4.9`

---
**Quick test:**

Prepare base HLF network:

> `./teardown.sh && ./generate.sh && ./start.sh`

Add new Org:

> **`./add-org.sh <org_name> <peer_7051_port> <peer_7053_port> <couchdb_5984_port> <ca_7054_port> <ca_admin_username> <ca_admin_password> <channel_name> <org_in_channel>`** \
> `./add-org.sh org3 15051 15053 15984 15054 Org3Admin Org3AdminPassword allarewelcome org1`

Add new Peer:

> **`./add-peer.sh <peer_name> <org_name> <peer_7051_port> <peer_7053_port> <couchdb_5984_port> <ca_admin_username> <ca_admin_password>`** \
> `./add-peer.sh peer1 org3 16051 16053 16984 Org3Admin Org3AdminPassword`

Create new channel:

> **`./create-channel.sh <channel_name> <list_of_orgs...>`** \
> `./create-channel.sh newchannel org2 org3`

Deploy and test chaincodes:

> **`./deploy-chaincode.sh <chaincode_path_in_cli> <chaincode_language> <chaincode_name> <chaincode_version/sequence_number> <channel_name> <org_in_channel>`** \
> `./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang allarewelcomecc 1 allarewelcome org1` \
> `./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang newchannelcc 1 newchannel org2`

Check the couchdb of any peer, for instance, peer1.org3:
  1. Access it in any browser - `localhost:15984/_utils`
  2. Use the credentials defined in the docker-compose file - `peer1.Org3:password`
  3. Check the databases referent to the deployed chaincodes - `allarewelcome_allarewelcomecc` and `newchannel_newchannelcc`
  4. Check if the key written at the end of the deploy-chaincode.sh script is there - `key1`
  5. Similarly, check the couchdbs of the other peers


---
**Other notes:**

In the previous example execution, note that **org1**, **org2** and **org3** are part of **allarewelcome**, but only **org2** and **org3** are part of **newchannel** - naturally, the couchdb of peers from **org1** will not have entries for the chaincode deployed to **newchannel**.

It is also interesting to see what happens if a new peer is added after chaincodes have been committed to the channel, let's try it:

Add a peer to **org3**:

> `./add-peer.sh peer2 org3 17051 17053 17984 Org3Admin Org3AdminPassword`

Check the couchdb of the newly added **peer2.org3**:
  1. Access it in any browser - `localhost:17984/_utils`
  2. Use the credentials defined in the docker-compose file - `peer2.Org3:password`
  3. Check the couchdb is updated with the databases referent to the deployed chaincodes - `allarewelcome_allarewelcomecc` and `newchannel_newchannelcc`
  4. Check if the key written at the end of the deploy-chaincode.sh script is there - `key1`

Test a chaincode invocation, with the participation of **peer2.org3**:

> `docker exec -e CORE_PEER_LOCALMSPID=Org2MSP -e CORE_PEER_ADDRESS=peer0.org2.example.com:7051 -e CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt -e CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -e CORE_PEER_TLS_CLIENTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt -e CORE_PEER_TLS_CLIENTKEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp cli peer chaincode invoke -o orderer0.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer0.example.com/tls/tlscacerts/tls-localhost-7054-ca-example-com.pem --channelID newchannel --name newchannelcc --peerAddresses peer0.org2.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --peerAddresses peer1.org2.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt --peerAddresses peer0.org3.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt --peerAddresses peer1.org3.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer1.org3.example.com/tls/ca.crt --peerAddresses peer2.org3.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer2.org3.example.com/tls/ca.crt -c '{"function":"set","args":["key1", "value1"]}' --waitForEvent`


---
**Comments and TODO:**

- Add ability to create new channels:
  - ~~**create-channel.sh**~~
  - ~~**add-peer.sh:** recognize channels org is a part of, and remove need to specify application channels~~
  - ~~**add-peer.sh:** peer should install the chaincodes that are running in the application channels the org belongs to~~
  - ~~**deploy-chaincode.sh:** remove need to specify list of orgs: use discovery service to fetch list of orgs in channel~~
  - ~~**deploy-chaincode.sh:** substitute long sleeps for periodic retries~~
  - ~~**README.md** should be updated to reflect all changes - for now it is only compatible with tag v1.0~~
  - handle the preliminary verifications and error checking the same way for all scripts