#!/bin/bash

HOSTS_FILE="hosts.txt"
OUTPUT_FILE="open_ports_summary.txt"
REMOTE_CMD="ss -tulnap | awk '{print \$1, \$2, \$5, \$6 }' | grep -v 127.0.0 | grep -v ::1 | grep -v 'WAIT'"
# optional | awk '{print \$1, \$2, \$5 }'

# Clear previous outputs
> "$OUTPUT_FILE"
> ssh_errors.log

echo "Gathering open ports from hosts in $HOSTS_FILE..."

while IFS= read -r HOST <&3 || [ -n "$HOST" ]; do
    echo "==== $HOST ====" >> "$OUTPUT_FILE"
    echo "Connecting to $HOST..."
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$HOST" "$REMOTE_CMD" >> "$OUTPUT_FILE" 2>>ssh_errors.log
    echo "" >> "$OUTPUT_FILE"
done 3< "$HOSTS_FILE"

echo "Done. Results saved to $OUTPUT_FILE"
echo "Any SSH errors are in ssh_errors.log"

