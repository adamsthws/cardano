#!/bin/bash

# CNCLI SLOT LEADER
# This script calculates the slot leader schedule for the upcoming epoch using cncli.
# Must be run with less than 1.5 days to go before the end of the current epoch.
# It runs at a low CPU priority (nice -n 19) to minimize impact on the node's performance.
# Assuming you're using the default CNTOOLS path you can simply run the script without altering any variables.

# Set your pool's env file
env_file="$CNODE_HOME/scripts/env"

##############################################
### DO NOT CHANGE ANYTHING BELOW THIS LINE ###
##############################################

# Get variables from env file
source "$env_file"
socket_path="$CARDANO_NODE_SOCKET_PATH"
pool_id="$POOL_FOLDER/$POOL_NAME/$POOL_ID_FILENAME"
vrf_skey="$POOL_FOLDER/$POOL_NAME/$POOL_VRF_SK_FILENAME"
byron_genesis="$BYRON_GENESIS_JSON"
shelley_genesis="GENESIS_JSON"
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
