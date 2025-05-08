#!/bin/bash

LOG_FILE="/var/log/syslog"

echo "Maintenance Mode Activity Report"
echo "========================================"
echo "Current Date/Time (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
echo "Current User: $USER"
echo "========================================"
echo

# Create a temporary file to store all maintenance events
TEMP_FILE=$(mktemp)

# Extract SSH CLI maintenance commands
grep 'management_console.ssh_command' "$LOG_FILE" | grep 'ghe-maintenance' | while read -r line; do
    TIMESTAMP=$(echo "$line" | awk '{print $1" "$2" "$3}')
    DATE_TIME=$(echo "$line" | grep -oP '"created_at": "\K[^"]+')
    HOSTNAME=$(echo "$line" | grep -oP '"hostname": "\K[^"]+')
    USER=$(echo "$line" | grep -oP '"mc_actor": "\K[^"]+')
    ACTOR_IP=$(echo "$line" | grep -oP '"actor_ip": "\K[^"]+')
    COMMAND=$(echo "$line" | grep -oP '"command": "\K[^"]+' | sed 's/\\n//g' | tr -d '\n\r')

    if [[ "$COMMAND" == "ghe-maintenance -s" ]]; then
        ACTION="Maintenance Mode ENABLED"
        METHOD="CLI (SSH)"
    elif [[ "$COMMAND" == "ghe-maintenance -u" ]]; then
        ACTION="Maintenance Mode DISABLED"
        METHOD="CLI (SSH)"
    else
        continue
    fi

    # Add to temp file with timestamp for sorting
    echo "$TIMESTAMP|$DATE_TIME|$HOSTNAME|$USER|$ACTOR_IP|$ACTION|$METHOD" >> "$TEMP_FILE"
done

# Extract Web UI maintenance banner commands
grep 'ghe-maintenance-banner' "$LOG_FILE" | grep 'task exec session starting' | while read -r line; do
    TIMESTAMP=$(echo "$line" | awk '{print $1" "$2" "$3}')
    DATE_TIME=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z')
    HOSTNAME=$(echo "$line" | awk '{print $4}' | sed 's/:$//')
    USER="Admin (Web UI)"
    ACTOR_IP="IP's are not captured from WebUI"
    
    if echo "$line" | grep -q "'bin/ghe-maintenance-banner' '-s'"; then
        ACTION="Maintenance Mode ENABLED"
        METHOD="Web UI"
    elif echo "$line" | grep -q "'bin/ghe-maintenance-banner' '-u'"; then
        ACTION="Maintenance Mode DISABLED"
        METHOD="Web UI"
    else
        continue
    fi

    # Add to temp file with timestamp for sorting
    echo "$TIMESTAMP|$DATE_TIME|$HOSTNAME|$USER|$ACTOR_IP|$ACTION|$METHOD" >> "$TEMP_FILE"
done

# Sort the events by timestamp and display in chronological order
sort -t '|' -k1,2 "$TEMP_FILE" | while IFS='|' read -r TIMESTAMP DATE_TIME HOSTNAME USER ACTOR_IP ACTION METHOD; do
    echo "Timestamp    : $TIMESTAMP"
    echo "Date/Time    : $DATE_TIME"
    echo "Hostname     : $HOSTNAME"
    echo "User         : $USER"
    echo "Actor IP     : $ACTOR_IP"
    echo "Action       : $ACTION"
    echo "Method       : $METHOD"
    echo "----------------------------------------"
done

# Clean up temporary file
rm -f "$TEMP_FILE"
