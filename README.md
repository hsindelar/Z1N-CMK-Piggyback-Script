# Z1N-CMK-Piggyback-Script

Unified CheckMK agent plugin for monitoring network switches and wireless access points through SNMP queries using CheckMK's piggyback mechanism.

## Overview

This script combines switch and AP monitoring into a single plugin. It queries network switches via SNMP to collect switch metrics (status, uptime, IP) and discovers connected access points via LLDP, reporting both as piggyback hosts to CheckMK for centralized monitoring without requiring agent installation on the devices.

## Features

- **Switch Monitoring**: Device status, uptime, and IP address tracking
- **AP Discovery**: Automatic detection of wireless access points via LLDP
- **Unified Solution**: Single script handles both switches and APs
- **Piggyback Integration**: Creates separate CheckMK hosts for each device
- **Error Handling**: Graceful handling of unreachable devices

## Script

### `piggyBack.sh`
Unified plugin script with two main functions:

#### `switch_piggyback()`
Monitors network switches and reports:
- Device reachability status (via SNMP)
- Device uptime (formatted as days, hours, minutes)
- Switch IP address

#### `ap_piggyback()`
Discovers and monitors access points via LLDP:
- AP hostname and IP address
- Device description/model information
- Parent switch relationship

## Requirements

- CheckMK agent installed on the monitoring host
- SNMP client tools (`snmpget`, `snmpwalk`)
- Network switches with:
  - SNMP v2c enabled
  - LLDP enabled and populated with neighbor data
  - Read access configured
- Read-only SNMP community string

## Configuration

Edit the script to configure your environment:

```bash
COMMUNITY="your_snmp_community"
SWITCHES="10.0.0.1 10.0.0.2 10.0.0.3"
```

**Variables:**
- `COMMUNITY`: SNMP community string for authentication
- `SWITCHES`: Space-separated list of switch IP addresses to query

## Installation

1. Copy `piggyBack.sh` to the CheckMK agent plugins directory:
   ```bash
   sudo cp piggyBack.sh /usr/local/lib/check_mk_agent/plugins/
   sudo chmod +x /usr/local/lib/check_mk_agent/plugins/piggyBack.sh
   ```

2. Configure your SNMP community and switch IPs in the script

3. Test the script manually:
   ```bash
   /usr/local/lib/check_mk_agent/plugins/piggyBack.sh
   ```

4. Perform service discovery in CheckMK to see the piggyback hosts

## How It Works

### Switch Monitoring
1. Iterates through configured switches
2. Queries SNMP OIDs:
   - `sysName.0` - Device hostname
   - `SYSUPTIME_OID` (1.3.6.1.2.1.1.3.0) - System uptime
3. Tests reachability before data collection
4. Outputs piggyback data with local checks

### AP Discovery
1. Queries LLDP MIBs on each switch:
   - `LLDP_REM_SYSNAME_OID` (1.0.8802.1.1.2.1.4.1.1.9) - Remote device hostname
   - `LLDP_REM_SYSDESC_OID` (1.0.8802.1.1.2.1.4.1.1.10) - Remote device description
   - `LLDP_REM_MANADDR_OID` (1.0.8802.1.1.2.1.4.2.1.4) - Remote device management IP
2. Filters results for AP-related keywords (AP, Cambium, WiFi)
3. Creates piggyback hosts for discovered APs

## CheckMK Piggyback Format

### Switch Output
```
<<<<SwitchHostname>>>>
<<<local>>>
0 Device-Status - SwitchHostname reachable via SNMP
0 Uptime - Uptime: 45d 12h 30m
0 IP-Address - IP: 10.0.0.1
<<<<>>>>
```

### AP Output
```
<<<<APHostname>>>>
<<<local>>>
0 IP-Address - IP: 10.0.0.100
0 AP-Info - Cambium Networks Access Point
0 Parent-Device - Name: SwitchName  IP: 10.0.0.1
<<<<>>>>
```

## AP Detection

The script identifies access points by matching keywords in the LLDP system description:
- `*AP*` or `*ap*`
- `*Cambium*`
- `*WiFi*`

Modify the case statement in the `ap_piggyback()` function to match your specific AP models.

## Use Cases

- **Unified Monitoring**: Single script for switches and APs
- **Network Topology**: Track AP-to-switch relationships
- **Automated Discovery**: No manual AP configuration needed
- **Centralized Management**: All devices monitored through CheckMK
- **Inventory Tracking**: Maintain up-to-date network device inventory

## Troubleshooting

**No switch output:**
- Verify SNMP community string is correct
- Check network connectivity to switches
- Ensure SNMP v2c is enabled on switches
- Verify firewall rules allow SNMP (UDP port 161)

**No AP discovery:**
- Verify LLDP is enabled on switches
- Check that APs are properly connected and advertising LLDP
- Test LLDP data manually: `snmpwalk -v2c -c <community> <switch_ip> 1.0.8802.1.1.2.1.4.1.1.9`
- Review AP detection patterns in the case statement

**Switches showing as unreachable:**
- Test SNMP manually: `snmpget -v2c -c <community> <switch_ip> sysName.0`
- Check SNMP access control lists on switches
- Verify correct community string

**Incorrect hostnames:**
- Check if `sysName.0` is properly configured on devices
- Script falls back to `switch_<IP>` for switches if hostname retrieval fails

## Extending the Script

To add additional monitoring metrics:

1. Define the SNMP OID
2. Add query in the appropriate function
3. Format and output the data

**Example - Adding switch temperature:**
```bash
TEMP_OID="1.3.6.1.4.1.9.9.13.1.3.1.3"
TEMP=$(snmpget -v2c -c "$COMMUNITY" -Oqv "$SW" "$TEMP_OID" 2>/dev/null)
echo "0 Temperature - Temp: ${TEMP}°C"
```

## License

MIT License - Feel free to modify and distribute

## Contributing

Pull requests welcome! Please test thoroughly in your environment before submitting.
