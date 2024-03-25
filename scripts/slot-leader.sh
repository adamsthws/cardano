#!/bin/bash

# This script calculates a the leader schedule for the next epoch using cncli.
# Must be run with less than 1.5 days to go before the end of the current epoch.
# It runs at a low CPU priority (nice -n 19) to minimize impact on the node's performance.

# Sets the pool name
env_file="$CNODE_HOME/scripts/env"
source "$env_file"
pool_name="$POOL_NAME"

# Set variables
socket_path="$CNODE_HOME/sockets/node0.socket"
pool_id="$CNODE_HOME/priv/pool/$pool_name/pool.id"
vrf_skey="$CNODE_HOME/priv/pool/$pool_name/vrf.skey"
byron_genesis="$CNODE_HOME/files/byron-genesis.json"
shelley_genesis="$CNODE_HOME/files/shelley-genesis.json"
db_path="$CNODE_HOME/guild-db/cncli/cncli.db"

# Capture stake-snapshot
stake_snapshot=$(nice -n 19 cardano-cli query stake-snapshot \
--socket-path $socket_path \
--stake-pool-id $(cat $pool_id) \
--mainnet)

# Parse stake values from the stake_snapshot
pool_stake=$(echo "$stake_snapshot" | jq 'first(.pools[]).stakeMark')
active_stake=$(echo "$stake_snapshot" | jq '.total.stakeMark')

# Execute cncli leaderlog calculation
nice -n 19 cncli leaderlog \
   --pool-id $(cat $pool_id) \
   --pool-vrf-skey $vrf_skey \
   --byron-genesis $byron_genesis \
   --shelley-genesis $shelley_genesis \
   --pool-stake "$pool_stake" \
   --active-stake "$active_stake" \
   --db $db_path \
   --consensus praos \
   --ledger-set next
