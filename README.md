# Adding nodes to Hyperledger Fabric networks

This was a small project to learn how to add Orgs and Peers to a local Hyperledger Fabric network. This project is based on the finalized laboratoriies of the TLF HLF for Administrators Course

**Requirements:**
- Docker 
- Docker Compose
- fabric-samplees (in the `~/Desktop`)

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


---
**Comments and TODO:**

- `org1.example.com` and `org2.example.com` belong to the base HLF network in this project, and their credentials are generated with cryptogen. Since the `add-org.sh` and `add-peer.sh` are implemented to use the CAs of the Orgs being manipulated, to generate the required cryptographic certificates, adding a peer to `org1.example.com` or `org2.example.com` is still not possible. 