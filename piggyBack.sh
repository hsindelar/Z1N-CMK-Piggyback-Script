#!/bin/sh
export PATH="/usr/local/bin:/usr/bin:/bin"

# Unified CMK Piggyback script. Fetches SNMP data from switches to piggyback the switches and APs into CMK

# Enter SNMP V2 community string and switch IPs (seperated by a space)
COMMUNITY="" SWITCHES=""

# AP Discovery LLDP MIBs
LLDP_REM_SYSNAME_OID="1.0.8802.1.1.2.1.4.1.1.9"
LLDP_REM_SYSDESC_OID="1.0.8802.1.1.2.1.4.1.1.10"
LLDP_REM_MANADDR_OID="1.0.8802.1.1.2.1.4.2.1.4"

# Switch Discovery OIDs
SYSUPTIME_OID="1.3.6.1.2.1.1.3.0"
IPADDR_OID="1.3.6.1.2.1.4.20.1.1"

switch_piggyback() {
    for SW in $SWITCHES; do
        HOSTNAME=$(snmpget -v2c -c "$COMMUNITY" -Oqv "$SW" sysName.0 2>/dev/null)
        [ -z "$HOSTNAME" ] && HOSTNAME="switch_${SW}"

        # Test SNMP reachability
        snmpget -v2c -c "$COMMUNITY" -Oqv "$SW" "$SYSUPTIME_OID" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            REACHABLE=0
        else
            REACHABLE=1
        fi

        echo "<<<<${HOSTNAME}>>>>"
        echo "<<<local>>>"

        # 1. Device status
        if [ "$REACHABLE" -eq 1 ]; then
            echo "0 Device-Status - ${HOSTNAME} reachable via SNMP"
        else
            echo "2 Device-Status - ${HOSTNAME} not reachable via SNMP"
            echo "<<<<>>>>"
            continue
        fi

        # 2. Device uptime
        UPTIME_RAW=$(snmpget -v2c -c "$COMMUNITY" -Oqv "$SW" "$SYSUPTIME_OID" 2>/dev/null)
        if echo "$UPTIME_RAW" | grep -q ':'; then
            DAYS=$(echo "$UPTIME_RAW" | cut -d':' -f1)
            HOURS=$(echo "$UPTIME_RAW" | cut -d':' -f2)
            MINS=$(echo "$UPTIME_RAW" | cut -d':' -f3)
        else
            SECS=$(expr "$UPTIME_RAW" / 100 2>/dev/null)
            DAYS=$(expr "$SECS" / 86400)
            HOURS=$(expr \( "$SECS" % 86400 \) / 3600)
            MINS=$(expr \( "$SECS" % 3600 \) / 60)
        fi
        echo "0 Uptime - Uptime: ${DAYS}d ${HOURS}h ${MINS}m"

        # 3. Switch IP address
        IP_ADDR="$SW"
        echo "0 IP-Address - IP: $IP_ADDR"

        echo "<<<<>>>>"
    done
}

ap_piggyback() {
    for SW in $SWITCHES; do
        switchName=$(snmpget -v2c -c "$COMMUNITY" -Oqv "$SW" sysName.0 2>/dev/null)
        [ -z "$switchName" ] && switchName="$SW"

        descArray=$(snmpwalk -v2c -c "$COMMUNITY" -Oqv "$SW" "$LLDP_REM_SYSDESC_OID" 2>/dev/null)
        nameArray=$(snmpwalk -v2c -c "$COMMUNITY" -Oqv "$SW" "$LLDP_REM_SYSNAME_OID" 2>/dev/null)
        ipArray=$(snmpwalk -v2c -c "$COMMUNITY" -On "$SW" "$LLDP_REM_MANADDR_OID" 2>/dev/null \
            | sed -nE 's/.*\.1\.4\.([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) =.*/\1/p')

        IFS='
    '
        set -f
        set -- $nameArray
        nameList="$*"
        nameCount=$#

        descList=$(echo "$descArray" | awk NF)
        ipList=$(echo "$ipArray" | awk NF)

        idx=1
        echo "$nameArray" | while IFS= read -r name; do
            desc=$(echo "$descList" | sed -n "${idx}p")
            ip=$(echo "$ipList" | sed -n "${idx}p")

            # Skip if description does not mention an AP or WiFi
	    if ! echo "$desc" | grep -qiE "AP|WiFi"; then
            	idx=$((idx + 1))
                continue
            fi


            # Strip surrounding double quotes if present
            cleanName=$(echo "$name" | sed 's/^"//; s/"$//')

            case "$desc" in
                *AP*|*ap*|*Cambium*|*WiFi*)
                    echo "<<<<${cleanName}>>>>"
                    echo "<<<local>>>"
                    echo "0 IP-Address - IP: ${ip:-N/A}"
                    echo "0 AP-Info - ${desc:-N/A}"
                    echo "0 Parent-Device - Name: ${switchName}  IP: ${SW}"
                    echo "<<<<>>>>"
                    ;;
            esac
            idx=$((idx + 1))
        done
    done
}

switch_piggyback
ap_piggyback
