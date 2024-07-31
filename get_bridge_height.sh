#!/bin/bash

# node_exporter metrics file path
metrics_file="$HOME/metrics/node_exporter_metrics.prom"
SLEEP_INTERVAL="1s"

function main() {
  temp_file=$(mktemp)

  # Function to calculate time difference in seconds
  function calculate_time_difference {
      local now=$(date +%s)
      local date_str="$1 $2 $3"
      local date_timestamp=$(date -d "$date_str" +%s)
      local difference=$((now - date_timestamp))
      echo "$difference"
  }

  # Obtain bridge height
  height=$(journalctl -u nubit-bridge.service -q | grep 'INFO.*header/store.*new head' | tail -n 1 | awk -F 'height": ' '{print $2}' | awk -F ',' '{print $1}')
  # Define HELP and TYPE
  help_comment="# HELP bridge_height Bridge node block height"
  type_comment="# TYPE bridge_height gauge"
  # save
  {
      echo "$help_comment"
      echo "$type_comment"
      echo "bridge_height $height"
  } >> "$temp_file"


  # The last version running on nubit
  last_vers_danode=$(sudo journalctl -u nubit-bridge.service | grep "node version:" | tail -n 1 | awk '{print substr($NF, 2)}' | tr -d '.' | awk '{print $1 / 10}')
  # Define HELP y TYPE
  help_comment="# HELP last_vers_danode The last version running on nubit Bridge"
  type_comment="# TYPE last_vers_danode gauge"
  # Save last_vers_danode
  {
      echo "$help_comment"
      echo "$type_comment"
      echo "last_vers_danode $last_vers_danode"
  } >> "$temp_file"

  # Counting the number of network connectivity timeout errors
  num_err_timeout_connectivity=$(sudo journalctl -p err | grep 'Timeout occurred while waiting for network connectivity' | wc -l)
  # Define HELP and TYPE
  help_comment="# HELP num_err_timeout_connectivity Counting the number of network connectivity timeout errors"
  type_comment="# TYPE num_err_timeout_connectivity gauge"
  # Save
  {
      echo "$help_comment"
      echo "$type_comment"
      echo "num_err_timeout_connectivity $num_err_timeout_connectivity"
  } >> "$temp_file"

  # Counting the number of closed connections per remote host
  num_closed_remote_host=$(sudo journalctl -p err | grep -c 'Connection closed by remote host')
  # Define HELP and TYPE for num_closed_remote_host
  help_comment="# HELP num_closed_remote_host Counting the number of closed connections per remote host"
  type_comment="# TYPE num_closed_remote_host gauge"
  # Save num_closed_remote_host metrics to file
  {
      echo "$help_comment"
      echo "$type_comment"
      echo "num_closed_remote_host $num_closed_remote_host"
  } >> "$temp_file"

  # Counting the number of time stamp analysis errors
  num_failed_parse_timestamp=$(sudo journalctl -p err | grep -c "Failed to parse timestamp: '1")
  # Define HELP and TYPE for num_failed_parse_timestamp
  help_comment="# HELP num_failed_parse_timestamp Counting the number of time stamp analysis errors"
  type_comment="# TYPE num_failed_parse_timestamp gauge"
  # Save num_failed_parse_timestamp metrics to file
  {
      echo "$help_comment"
      echo "$type_comment"
      echo "num_failed_parse_timestamp $num_failed_parse_timestamp"
  } >> "$temp_file"

  # # Obtain connection status
  # status=$(sudo journalctl -u nubit-bridge.service | grep "CANONICAL_PEER_STATUS:" | awk -F'connection_status="' '{print $2}' | cut -d'"' -f1 | tail -n 1)
  # # Define HELP and TYPE for connection status
  # help_comment_status="# HELP connection_status Connection status of the bridge node (1 for established, 0 otherwise)"
  # type_comment_status="# TYPE connection_status gauge"
  # # Determine connection status value (1 if established, 0 otherwise)
  # if [ "$status" = "established" ]; then
  #     connection_status_value=1
  # else
  #     connection_status_value=0
  # fi
  # # Save
  # {
  #     echo "$help_comment_status"
  #     echo "$type_comment_status"
  #     echo "connection_status $connection_status_value"
  # } >> "$temp_file"

  # Obtain chain_id_danode status
  chain_id_danode=$(sudo journalctl -u nubit-bridge.service | grep "network:" | awk '{if ($NF == "nubit-alphatestnet-1") print 0; else if ($NF == "nubit") print 1}' | tail -n 1)
  # Define HELP and TYPE for chain_id_danode
  help_comment_chain_id="# HELP chain_id_danode Network status of the bridge node (1 for mainnet, 0 for testnet)"
  type_comment_chain_id="# TYPE chain_id_danode gauge"
  # Save metrics to the file
  {
      echo "$help_comment_chain_id"
      echo "$type_comment_chain_id"
      echo "chain_id_danode $chain_id_danode"
  } >> "$temp_file"

  # Time since last connection closed by remote host
  last_closed_remote_host=$(sudo journalctl -p err | awk '/Connection closed by remote host/ {date=$1 " " $2 " " $3} END {print date}')
  if [ -n "$last_closed_remote_host" ]; then
      time_last_closed_remote_host=$(calculate_time_difference $last_closed_remote_host)
  else
      time_last_closed_remote_host=0
  fi
  echo "# HELP time_last_closed_remote_host Time since last connection closed by remote host" >> "$temp_file"
  echo "# TYPE time_last_closed_remote_host gauge" >> "$temp_file"
  echo "time_last_closed_remote_host $time_last_closed_remote_host" >> "$temp_file"

  # Time since last network connectivity timeout error
  last_timeout_connectivity=$(sudo journalctl -p err | awk '/Timeout occurred while waiting for network connectivity/ {date=$1 " " $2 " " $3} END {print date}')
  if [ -n "$last_timeout_connectivity" ]; then
      time_last_timeout_connectivity=$(calculate_time_difference $last_timeout_connectivity)
  else
      time_last_timeout_connectivity=0
  fi
  echo "# HELP time_last_err_timeout_connectivity Time since last network connectivity timeout error" >> "$temp_file"
  echo "# TYPE time_last_err_timeout_connectivity gauge" >> "$temp_file"
  echo "time_last_err_timeout_connectivity $time_last_timeout_connectivity" >> "$temp_file"

  # Time since last failed parse timestamp
  last_failed_parse_timestamp=$(sudo journalctl -p err | awk '/Failed to parse timestamp/ {date=$1 " " $2 " " $3} END {print date}')
  if [ -n "$last_failed_parse_timestamp" ]; then
      time_last_failed_parse_timestamp=$(calculate_time_difference $last_failed_parse_timestamp)
  else
      time_last_failed_parse_timestamp=0
  fi
  echo "# HELP last_failed_parse_timestamp Time since last connection closed by remote host" >> "$temp_file"
  echo "# TYPE last_failed_parse_timestamp gauge" >> "$temp_file"
  echo "last_failed_parse_timestamp $time_last_failed_parse_timestamp" >> "$temp_file"

  # Time when nubit DA node started
  date_started_danode=$(sudo journalctl -u nubit-bridge.service | grep "Started nubit bridgenode" | tail -n 1 | awk '{ "date -d \""$1" "$2" "$3"\" +\"%s\"" | getline date; print date}')

  # Get current timestamp
  now=$(date +%s)

  # Calculate difference if date_started_danode is not empty
  if [ -n "$date_started_danode" ]; then
      difference=$((now - date_started_danode))
  fi

  # HELP & TYPE
  help_comment="# HELP time_since_nubit_danode_started Time since nubit DA node started"
  type_comment="# TYPE time_since_nubit_danode_started gauge"

  # Read previous value of time_since_nubit_danode_started
  previous_value=$(grep "^time_since_nubit_danode_started " "$metrics_file" | awk '{print $2}')

  # Save only if date_started_danode is not empty
  if [ -n "$date_started_danode" ]; then
      {
          echo "$help_comment"
          echo "$type_comment"
          echo "time_since_nubit_danode_started $difference"
      } >> "$temp_file"
  else
      # If date_started_danode is empty, write the previous value back
      if [ -n "$previous_value" ]; then
          {
              echo "$help_comment"
              echo "$type_comment"
              echo "time_since_nubit_danode_started $previous_value"
          } >> "$temp_file"
      fi
  fi

  mv "$temp_file" "$metrics_file"

  sleep $SLEEP_INTERVAL
}

while true ; do main ; done
