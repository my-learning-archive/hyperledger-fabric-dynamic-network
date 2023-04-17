# Dynamic HLF Network

The goal of this project was to create a quick-to-set dynamic HLF network, to provide an easy to use, flexible development environment for HLF-based applications.

**Requirements:**
- Docker 
- Docker Compose v2
- fabric-samples (in the `~/Desktop`)
- yq tool


---
**Before start:**

Install basic requirements:
> `sudo apt-get update` \
> `sudo apt-get install curl git python-minimal apt-transport-https ca-certificates gnupg-agent software-properties-common` 

Install Docker and Docker Compose v2:
> `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -` \
> `sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"` \
> `sudo apt-get update` \
> `sudo apt-get -y install docker-ce docker-ce-cli docker-compose-plugin` \
> `sudo groupadd docker` \
> `sudo usermod -aG docker $USER && newgrp docker`

Install yq:
> `sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64` \
> `sudo chmod a+x /usr/local/bin/yq`

Install the fabric-samples in the `~/Desktop/` directory:

> `cd ~/Desktop` \
> `curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.6 1.4.9`

Copy the *sacc* chaincode to `./chaincodes/` directory:

> `cd <the directory of this README.md>` \
> `cp -r ~/Desktop/fabric-samples/chaincode/sacc ./chaincodes/`


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

Add new User:

> **`./create-user.sh <org_name> <user_username> <user_password> <ca_admin_username> <ca_admin_password> <user_role>`** \
> `./create-user.sh org3 NewUser NewUserPassword Org3Admin Org3AdminPassword WRITER`

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
**Hard test:**

> `./teardown.sh && ./generate.sh && ./start.sh && ./create-org.sh org3 15051 15053 15984 15054 Org3Admin Org3AdminPassword allarewelcome org1 && ./create-peer.sh peer1 org3 16051 16053 16984 Org3Admin Org3AdminPassword && ./create-channel.sh newchannel org2 org3 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang allarewelcomecc 1 allarewelcome org1 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang newchannelcc 1 newchannel org2 && ./create-peer.sh peer2 org3 17051 17053 17984 Org3Admin Org3AdminPassword && ./create-org.sh org4 20051 20053 20984 20054 Org4Admin Org4AdminPassword newchannel org3 && sleep 30 && ./create-org.sh org5 25051 25053 25984 25054 Org5Admin Org5AdminPassword newchannel org4 && ./create-peer.sh peer1 org5 30051 30054 30984 Org5Admin Org5Password && ./create-channel.sh anothernewchannel org1 org3 org5 && sleep 30 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang anothernewchannelcc 1 anothernewchannel org5 && ./create-channel.sh themegachannel org1 org2 org3 org4 org5 && sleep 30 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang themegachaincode 1 themegachannel org5 && ./deploy-chaincode.sh /opt/gopath/src/github.com/chaincode/sacc golang anothermegachaincode 1 themegachannel org3`


---
**Comments:**

- Place chaincodes in the `./chaincodes/` directory, as it is mapped to the `/opt/gopath/src/github.com/chaincode/` directory, inside the *cli* container. Place the corresponding APIs in the `./apis/` directory. For example: as preliminary step before running the commands in this README, the *sacc* chaincode was copied to the `./chaincodes/sacc/` directory - if a corresponding client API is to be implemented, it is recommended to be in the `./apis/sacc/` directory.


---
**TODOs:**

- Implement script to join existing orgs to existing channels
- Figure out how to allow users to invoke chaincode, via a corresponding client API, while authenticating themselves when `CORE_PEER_TLS_CLIENTAUTHREQUIRED=true` is set in the peer nodes.