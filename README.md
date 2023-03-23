# Adding nodes to Hyperledger Fabric networks

This was a small project to learn how to add Orgs and Peers to a local Hyperledger Fabric network. This project is based on the finalized laboratoriies of the TLF HLF for Administrators Course

**Requirements:**
- Docker 
- Docker Compose
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

> **`./add-org.sh <org_name> <peer_7051_port> <peer_7053_port> <couchdb_5984_port> <ca_7054_port> <channel_name> <ca_admin_username> <ca_admin_password>`** \
> `./add-org.sh org3 15051 15053 15984 15054 allarewelcome Org3Admin Org3AdminPassword`

Add new Peer:

> **`./add-peer.sh <peer_name> <org_name> <peer_7051_port> <peer_7053_port> <couchdb_5984_port> <channel_name> <ca_admin_username> <ca_admin_password>`** \
> `./add-peer.sh peer1 org3 16051 16053 16984 allarewelcome Org3Admin Org3AdminPassword`

Deploy and test chaincode:

> **`./deploy-chaincode.sh <chaincode_path_in_cli> <chaincode_language> <chaincode_name> <chaincode_version/sequence_number> <channel_name> <list_of_orgs...>`** \
> `./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang sacc 1 allarewelcome org1 org2 org3`

Check the couchdb of any peer, for instance, peer1.org3:
  1. Access it in any browser - `localhost:15984/_utils`
  2. Use the credentials defined in the docker-compose file - `peer1.Org3:password`
  3. Check the database referent to the deployed chaincode - `allarewelcome_sacc`
  4. Check if the key written at the end of the deploy-chaincode.sh script is there - `key1`
  5. Similarly, check the couchdbs of the other peers

---
**Comments and TODO:**

- Script to create other channels.