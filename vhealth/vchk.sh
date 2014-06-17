#!/usr/bin/env bash

if [[ "$#" -lt "2" ]]; then
	echo "Usage: $0 <hostname> <internal_ip>"
	echo $@
	exit 3
else
	/opt/vertica/bin/vsql -h $1 -U dbadmin -w YGtQaRSdGrVe1g -d openx -Atc "select node_state from nodes where node_address = '$2' LIMIT 1;"
fi

