# vm-subnet-mover

A PowerShell script that moves a Windows VM (or any networked device) to a new subnet. It preserves the last octet of the current IP address, applies the new subnet prefix, sets the subnet mask, and configures DNS servers — all in one step.

## Requirements

- Windows with PowerShell 5.1 or PowerShell 7+
- Administrator privileges (required to modify network adapter settings)
- The `NetTCPIP` and `DnsClient` PowerShell modules (included with Windows by default)

## Parameters

| Parameter | Required | Description |
|---|---|---|
| `-DestinationSubnet` | Yes | First three octets of the destination subnet (e.g. `192.168.10`) |
| `-SubnetMask` | Yes | Subnet mask for the destination network in dotted-decimal (e.g. `255.255.255.0`) |
| `-DnsServers` | Yes | Comma-separated list of exactly two DNS server IP addresses (e.g. `8.8.8.8,8.8.4.4`) |

## Usage

```powershell
.\vm-subnet-mover.ps1 `
    -DestinationSubnet "192.168.10" `
    -SubnetMask "255.255.255.0" `
    -DnsServers "8.8.8.8,8.8.4.4"
```

### Preview changes without applying them (`-WhatIf`)

```powershell
.\vm-subnet-mover.ps1 `
    -DestinationSubnet "192.168.10" `
    -SubnetMask "255.255.255.0" `
    -DnsServers "8.8.8.8,8.8.4.4" `
    -WhatIf
```

### Verbose output

```powershell
.\vm-subnet-mover.ps1 `
    -DestinationSubnet "192.168.10" `
    -SubnetMask "255.255.255.0" `
    -DnsServers "8.8.8.8,8.8.4.4" `
    -Verbose
```

## How It Works

1. Validates all three input parameters
2. Detects the current non-loopback IPv4 address on the machine
3. Preserves the last octet of the current IP and prepends the destination subnet to form the new IP
   - Example: current IP `172.16.5.42` + destination subnet `10.20.30` → new IP `10.20.30.42`
4. Logs the current IP and the new IP it is changing to
5. Removes the existing IP address from the adapter
6. Assigns the new IP address with the specified subnet mask
7. Sets the DNS servers on the adapter
8. Logs success or any errors encountered

## Example Output

```
[2024-03-15 10:22:01] Current IP address : 172.16.5.42
[2024-03-15 10:22:01] New IP address     : 10.20.30.42 (subnet 10.20.30, mask 255.255.255.0)
[2024-03-15 10:22:01] DNS servers        : 8.8.8.8, 8.8.4.4
[2024-03-15 10:22:02] IP address successfully changed from 172.16.5.42 to 10.20.30.42.
[2024-03-15 10:22:02] DNS servers successfully set to 8.8.8.8, 8.8.4.4.
```

## Running Tests

Tests are written using [Pester](https://pester.dev/) v5.

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester ./tests/
```
