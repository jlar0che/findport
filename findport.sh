#!/bin/bash

# FindPort
# v0.1
# by Jacques Laroche

# Check if a port number was provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <port_number>"
    exit 1
fi

PORT="$1"

# Find all docker-compose.yml files (excluding any under directories named "portainer")
find . -type d -name "portainer" -prune -false -o -type f -name "docker-compose.yml" -exec grep -H --color=always -P "(?<!\d)${PORT}(?!\d)" {} + | awk -F: '{
    file=$1
    sub(/:/,"",file)
    print "Found port '"$PORT"' in: " file
    print "Matched line: " $2
    print "----------------------------------------"
}'
