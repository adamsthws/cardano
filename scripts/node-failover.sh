#!/bin/bash

# Run this script on your hot-spare block producer.
# It will test if your main block producer is live. 
# If offline, block production on the hot-spare is activated until the main BP comes back online.

# Adapted from Andrew Westberg's Script to make it easier for Guild Tools (cntools) users.
# https://gist.github.com/AndrewWestberg/d982fb1304db36df8c484599180bd9e2

# Leave blank if you don't have something like postfix enabled to send emails from the host.
notification_email=""

# Set the path to your block producer files
credentials_kes_file_active=/path/to/kes.skey
credentials_vrf_file_active=/path/to/vrf.skey
credentials_opcert_file_active=/path/to/node.opcert
credentials_kes_file_standby=/path/to/kes.skey.standby
credentials_vrf_file_standby=/path/to/vrf.skey.standby
credentials_opcert_file_standby=/path/to/node.opcert.standby

# Set the name of the systemd cardano-node service 
# Guild tools uses 'cnode.service'. Others may use 'node.service'
cardano_node_service=cnode.service

# Set the EKG port (Default = 12788)
ekg_port=12788

# Set the address (hostname/IP) of the node to test
node_to_test_address=192.168.x.x

# Set the port number of the node to test
node_to_test_port=3001

# Check for required commands
required_cmds=("curl" "jq" "cp" "kill" "mv")
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Required command '$cmd' not found on the system."
    exit 1
  fi
done

# Get the cardano-node process ID
service_pid=`systemctl show --property MainPID --value $cardano_node_service`

# Determine if leading/forging - If so, this value from EKG will increase over a 3 second time period
leader_checks_1=`curl -H "Accept: application/json" http://127.0.0.1:${ekg_port} 2>/dev/null | jq '.cardano.node.metrics.Forge."node-not-leader".int.val'`
sleep 3
leader_checks_2=`curl -H "Accept: application/json" http://127.0.0.1:${ekg_port} 2>/dev/null | jq '.cardano.node.metrics.Forge."node-not-leader".int.val'`

if [[ $leader_checks_2 -gt $leader_checks_1 ]]
then
	is_leading=1
	#echo "ACTIVE mode. checking..."
else
	is_leading=0
	#echo "STANDBY mode. checking..."
fi

# Locate cncli
cncli_cmd=$(which cncli 2>/dev/null)

# Check if cncli is found
if [ -z "$cncli_cmd" ]; then
  echo "cncli not found. Please ensure it is installed and accessible."
  exit 1
fi

# Locate mail
mail_cmd=$(which mail)

# Test if the remote node is online
error=`$cncli_cmd ping --host ${node_to_test_address} --port ${node_to_test_port} | jq .status | grep error | wc -l`
if [[ $error -eq 1 ]]
then
	#echo "relay0 error. check relay1..."
	#sleep 10
	#error=`$cncli_path ping --host ${node2_to_test_address} --port ${node2_to_test_port} | jq .status | grep error | wc -l`
	#if [[ $error -eq 1 ]]
	#then
		if [[ $is_leading -eq 0 ]]
		then
      # Activate block production on the hot spare
			echo "$(date): Enter ACTIVE mode..."
			cp -f $credentials_kes_file_standby $credentials_kes_file_active
			cp -f $credentials_vrf_file_standby $credentials_vrf_file_active
			cp -f $credentials_opcert_file_standby $credentials_opcert_file_active
			kill -s HUP $service_pid
      # Send email notification
      if [[ -n "$mail_cmd" && -n "$notification_email" ]]
      then
        $mail_cmd -s "Cardano Failover Activated!" ${notification_email} <<< "Cardano failover block producer has been activated!"
      fi
		fi
		exit 0
	#fi
fi

# Turn off block production on the hot spare
if [[ $is_leading -eq 1 ]]
then
	# Hot spare is currently active but shouldn't be.
	echo "$(date): Return to STANDBY mode..."
	mv -f $credentials_kes_file_active $credentials_kes_file_standby
	mv -f $credentials_vrf_file_active $credentials_vrf_file_standby
	mv -f $credentials_opcert_file_active $credentials_opcert_file_standby
	kill -s HUP $service_pid
  # Send email notification
  if [[ -n "$mail_cmd" && -n "$notification_email" ]]
  then
    $mail_cmd -s "Cardano Failover Deactivated!" ${notification_email} <<< "Cardano failover block producer has been deactivated!"
  fi
fi

