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

> **`./create-org.sh <org_name> <peer_7051_port> <peer_7053_port> <couchdb_5984_port> <ca_7054_port> <ca_admin_username> <ca_admin_password> <channel_name> <org_in_channel>`** \
> `./create-org.sh org3 15051 15053 15984 15054 Org3Admin Org3AdminPassword allarewelcome org1`

Add new Peer:

> **`./create-peer.sh <peer_name> <org_name> <peer_7051_port> <peer_7053_port> <couchdb_5984_port> <ca_admin_username> <ca_admin_password>`** \
> `./create-peer.sh peer1 org3 16051 16053 16984 Org3Admin Org3AdminPassword`

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
**A hard test:**

> `./teardown.sh && ./generate.sh && ./start.sh && ./create-org.sh org3 15051 15053 15984 15054 Org3Admin Org3AdminPassword allarewelcome org1 && ./create-peer.sh peer1 org3 16051 16053 16984 Org3Admin Org3AdminPassword && ./create-channel.sh newchannel org2 org3 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang allarewelcomecc 1 allarewelcome org1 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang newchannelcc 1 newchannel org2 && ./create-peer.sh peer2 org3 17051 17053 17984 Org3Admin Org3AdminPassword && ./create-org.sh org4 20051 20053 20984 20054 Org4Admin Org4Password newchannel org3 && sleep 30 && ./create-org.sh org5 25051 25053 25984 25054 Org5Admin Org5Password newchannel org4 && ./create-peer.sh peer1 org5 30051 30054 30984 Org5Admin Org5Password && ./create-channel.sh anothernewchannel org1 org3 org5 && sleep 30 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang anothernewchannelcc 1 anothernewchannel org5 && ./create-channel.sh themegachannel org1 org2 org3 org4 org5 && sleep 30 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang themegachaincode 1 themegachannel org5 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang anothermegachaincode 1 themegachannel org3`


---
**Comments and TODO:**

- Add ability to create new channels:
  - ~~**create-channel.sh**~~
  - ~~**add-peer.sh:** recognize channels org is a part of, and remove need to specify application channels~~
  - ~~**add-peer.sh:** peer should install the chaincodes that are running in the application channels the org belongs to~~
  - ~~**deploy-chaincode.sh:** remove need to specify list of orgs: use discovery service to fetch list of orgs in channel~~
  - ~~**deploy-chaincode.sh:** substitute long sleeps for periodic retries~~
  - ~~**README.md** should be updated to reflect all changes - for now it is only compatible with tag v1.0~~
  - ~~handle the preliminary verifications and error checking the same way for all scripts~~
  - Implement script to join existing orgs to existing channels
  - Migrate some global variables such as $CLI_CONTAINER and $ORDERER_CONTAINER_HOSTNAME_PORT to the .env file