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

# Import env file
source "$env_file"

# Calculate how long until the end of the current epoch...

# Get current slot number
getEpoch(){
 "$CCLI" query tip --mainnet | sed -n '3 p'| sed 's/[^0-9]*//g'
}

# Format to human readable output - days, hours, minutes and seconds
timeLeft() {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  local timeString=""

  # Show days, hours, minutes, and seconds
  [[ $D -gt 0 ]] && timeString+="${D}d "
  timeString+=$(printf '%02dh %02dm' $H $M)

  echo $timeString
}

# Calculate time left to end of current epoch
calculateTimeLeft() {
  # Mainnet parameters (Testnet may vary)
  SHELLEY_TRANS_EPOCH=208
  BYRON_SLOT_LENGTH=20000
  BYRON_EPOCH_LENGTH=21600
  SLOT_LENGTH=1
  EPOCH_LENGTH=432000
  BYRON_GENESIS_START_SEC=1506203091

  current_time_sec=$(date +%s)
  time_left=$(( ((SHELLEY_TRANS_EPOCH * BYRON_SLOT_LENGTH * BYRON_EPOCH_LENGTH) / 1000) + (($(getEpoch) + 1 - SHELLEY_TRANS_EPOCH) * SLOT_LENGTH * EPOCH_LENGTH) - current_time_sec + BYRON_GENESIS_START_SEC ))

  echo $time_left
}

# If time left is more than 1.5 days, do not continue.
timeLeftUntilEnd=$(calculateTimeLeft)
formattedTimeLeft=$(timeLeft $timeLeftUntilEnd)

if [ $timeLeftUntilEnd -gt 129600 ]; then
  echo "Slot leader schedule for the next epoch can only be calculated when there is less than 1.5 days until the end of the epoch."
  additionalTime=$((timeLeftUntilEnd - 129600))
  echo "Current epoch ends in $formattedTimeLeft... Try again in another $(timeLeft $additionalTime)."
  exit 1
fi

# Calculate slot leader schedule...

# Set variables (obtained from the previously imported env file).
socket_path="$CARDANO_NODE_SOCKET_PATH"
pool_id="$POOL_FOLDER/$POOL_NAME/$POOL_ID_FILENAME"
vrf_skey="$POOL_FOLDER/$POOL_NAME/$POOL_VRF_SK_FILENAME"
byron_genesis="$BYRON_GENESIS_JSON"
shelley_genesis="$GENESIS_JSON"
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
