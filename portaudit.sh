#!/bin/bash

HOSTS_FILE="hosts.txt"
LISTEN_FILE="open_ports_listen_uconn.txt"
ESTAB_FILE="open_ports_established.txt"
REMOTE_CMD="ss -tulnap | grep -v 127.0.0 | grep -v ::1 | grep -v WAIT"

# Clear old outputs
> "$LISTEN_FILE"
> "$ESTAB_FILE"
> ssh_errors.log

while IFS= read -r HOST <&3 || [ -n "$HOST" ]; do
    echo "==== $HOST ====" >> "$LISTEN_FILE"
    echo "==== $HOST ====" >> "$ESTAB_FILE"

    echo "Connecting to $HOST..."
    
    # Grab all ss output
    ALL_OUTPUT=$(ssh -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$HOST" "$REMOTE_CMD" 2>>ssh_errors.log)
    
    # Split into two categories
    echo "$ALL_OUTPUT" | grep -E 'LISTEN|UNCONN' >> "$LISTEN_FILE"
    echo "$ALL_OUTPUT" | grep 'ESTAB' >> "$ESTAB_FILE"

    echo "" >> "$LISTEN_FILE"
    echo "" >> "$ESTAB_FILE"
done 3< "$HOSTS_FILE"

echo "Done."
echo "Listen & UDP servers saved to: $LISTEN_FILE"
echo "Established connections saved to: $ESTAB_FILE"
echo "Any SSH errors are in ssh_errors.log"

