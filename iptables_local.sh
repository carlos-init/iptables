#!/bin/bash

HOSTS_FILE="hosts.txt"
OPEN_PORTS_FILE="open_ports_all_local.txt"
IPTABLES_FILE="iptables_rules_local.sh"
ESTAB_LINES="established_lines.txt"

> "$OPEN_PORTS_FILE"
> "$IPTABLES_FILE"
> "$ESTAB_LINES"
REMOTE_CMD="ss -tulnap | grep -v :: | grep -v WAIT | sort "
#REMOTE_CMD="ss -tulnap | grep -v 127.0.0 | grep -v :: | grep -v WAIT" / The correct CMD for auditing remote hosts

while IFS= read -r HOST <&3 || [ -n "$HOST" ]; do
    echo "==== $HOST ====" >> "$OPEN_PORTS_FILE"

    if [ "$HOST" == "localhost" ] || [ "$HOST" == "127.0.0.1" ]; then
        ALL_OUTPUT=$(eval "$REMOTE_CMD")
    else
        echo "Skipping non-local host: $HOST"
        continue
    fi

    echo "$ALL_OUTPUT" | grep -v '\[::' >> "$OPEN_PORTS_FILE"
    echo "" >> "$OPEN_PORTS_FILE"
done 3< "$HOSTS_FILE"

# Generate iptables rules from LISTEN lines only
echo "#!/bin/bash" >> "$IPTABLES_FILE"
echo "" >> "$IPTABLES_FILE"
echo "iptables -F" >> "$IPTABLES_FILE"
echo "iptables -X" >> "$IPTABLES_FILE"
echo "iptables -P INPUT DROP" >> "$IPTABLES_FILE"
echo "iptables -P FORWARD DROP" >> "$IPTABLES_FILE"
echo "iptables -P OUTPUT ACCEPT" >> "$IPTABLES_FILE"
echo "" >> "$IPTABLES_FILE"

# Allow loopback and established
echo "iptables -A INPUT -i lo -j ACCEPT" >> "$IPTABLES_FILE"
echo "iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$IPTABLES_FILE"


while IFS= read -r LINE; do
    if [ -z "$LINE" ] || echo "$LINE" | grep -q "^==== "; then
        continue
    fi

    PROTO=$(echo "$LINE" | awk '{print $1}')
    STATE=$(echo "$LINE" | awk '{print $2}')
    ADDRPORT=$(echo "$LINE" | awk '{print $5}')
    #SRCADDR=$(echo "$LINE" | awk '{print $6}'| cut -d: -f1) / Leaving for potential future use.

    if [ "$STATE" = "ESTAB" ]; then 
        echo "$LINE" >> "$ESTAB_LINES"
        continue
    fi
    
    if [ "$STATE" = "LISTEN" ] || [ "$STATE" = "UNCONN" ]; then
        PORT=$(echo "$ADDRPORT" | awk -F':' '{print $NF}')
        SOMETHING_RETURN=0

        while IFS= read -r ESTAB_LINE; do
            
            #This is if you want a less strict set of iptable rules that dont all require a -s flag amd sourceip/subnet
            # if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" = $(echo "$ESTAB_LINE" | awk '{print $5}'| cut -d: -f2) ] ; then
            #     SRCADDR=$(echo "$ESTAB_LINE" | awk '{print $6}'| cut -d: -f1)
            #     echo "iptables -A INPUT -s $SRCADDR -p $PROTO --dport $PORT -j ACCEPT" >> "$IPTABLES_FILE"
            #     SOMETHING_RETURN=1
            # fi

            #This is for a more strict set or rules that requre a -s flag and source ip based on established connections
            if [[ "$PORT" =~ ^[0-9]+$ ]] ; then
                SRCADDR=$(echo "$ESTAB_LINE" | awk '{print $6}'| cut -d: -f1)
                echo "iptables -A INPUT -s $SRCADDR -p $PROTO --dport $PORT -j ACCEPT" >> "$IPTABLES_FILE"
                SOMETHING_RETURN=1
            fi

        done < "$ESTAB_LINES"

        if [ $SOMETHING_RETURN -eq 0 ]; then
            echo "iptables -A INPUT -p $PROTO --dport $PORT -j ACCEPT" >> "$IPTABLES_FILE"
        fi

    fi
done < "$OPEN_PORTS_FILE"

# Save the iptables rules persistently and checks for certain distros / IN THE WORKS
# echo "" >> "$IPTABLES_FILE"
# echo "if command -v iptables-save >/dev/null 2>&1; then" >> "$IPTABLES_FILE"
# echo "  if [ -d /etc/sysconfig ]; then" >> "$IPTABLES_FILE"
# echo "    iptables-save > /etc/sysconfig/iptables" >> "$IPTABLES_FILE"
# echo "  elif [ -d /etc/iptables ]; then" >> "$IPTABLES_FILE"
# echo "    iptables-save > /etc/iptables/rules.v4" >> "$IPTABLES_FILE"
# echo "  fi" >> "$IPTABLES_FILE"
# echo "fi" >> "$IPTABLES_FILE"

#This is for logging
echo "" >> "$IPTABLES_FILE"
echo "iptables -N LOG_DROP" >> "$IPTABLES_FILE"
echo "iptables -A LOG_DROP -j LOG --log-tcp-options --log-ip-options --log-prefix "[IPTABLES DROP] : "" >> "$IPTABLES_FILE"
echo "iptables -A LOG_DROP -j DROP" >> "$IPTABLES_FILE"
echo "iptables -A INPUT -p tcp -m tcp --dport 22 -m comment --comment "block everyone else" -j LOG_DROP COMMIT" >> "$IPTABLES_FILE"


#chmod +x "$IPTABLES_FILE" This automatically makese generated iptables rules file executable

echo "Done."
echo "Open ports written to: $OPEN_PORTS_FILE"
echo "Iptables rules written to: $IPTABLES_FILE"
echo ""

# this is to remove duplicate lines and the "tee" command echos the output of the final file
cat $IPTABLES_FILE | awk '{ if ($0 == "") { print; next } } !seen[$0]++' | tee $IPTABLES_FILE
