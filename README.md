# vm-subnet-mover

A PowerShell script that moves a Windows VM (or any networked device) to a new subnet. It accepts the destination network in CIDR notation, derives the subnet mask automatically, preserves the last octet of the current IP address, and configures DNS servers — all in one step.

## Requirements

- Windows with PowerShell 5.1 or PowerShell 7+
- Administrator privileges (required to modify network adapter settings)
- The `NetTCPIP` and `DnsClient` PowerShell modules (included with Windows by default)

## Parameters

| Parameter | Required | Description |
|---|---|---|
| `-DestinationSubnet` | Yes | Destination network in CIDR notation (e.g. `172.30.50.0/23`) |
| `-DnsServers` | Yes | Comma-separated list of exactly two DNS server IP addresses (e.g. `8.8.8.8,8.8.4.4`) |

The subnet mask is derived automatically from the CIDR prefix length — no need to provide it separately.

## Usage

```powershell
.\vm-subnet-mover.ps1 `
    -DestinationSubnet "172.30.50.0/23" `
    -DnsServers "8.8.8.8,8.8.4.4"
```

### Preview changes without applying them (`-WhatIf`)

```powershell
.\vm-subnet-mover.ps1 `
    -DestinationSubnet "172.30.50.0/23" `
    -DnsServers "8.8.8.8,8.8.4.4" `
    -WhatIf
```

### Verbose output

```powershell
.\vm-subnet-mover.ps1 `
    -DestinationSubnet "172.30.50.0/23" `
    -DnsServers "8.8.8.8,8.8.4.4" `
    -Verbose
```

## How It Works

1. Validates the CIDR notation input and DNS server addresses
2. Parses the CIDR string (e.g. `172.30.50.0/23`) into:
   - **Network address** — `172.30.50.0`
   - **Prefix length** — `23`
   - **Subnet mask** — derived automatically (`255.255.254.0`)
   - **Subnet prefix** — first three octets of the network address (`172.30.50`)
3. Detects the current non-loopback IPv4 address on the machine
4. Preserves the last octet of the current IP and prepends the subnet prefix to form the new IP
   - Example: current IP `192.168.1.42` + CIDR `172.30.50.0/23` → new IP `172.30.50.42`
5. Logs the current IP and the new IP it is changing to
6. Removes the existing IP address from the adapter
7. Assigns the new IP address with the mask derived from the CIDR prefix length
8. Sets the DNS servers on the adapter
9. Logs success or any errors encountered

## CIDR to Subnet Mask Reference

Some common CIDR prefix lengths and their corresponding masks:

| CIDR | Subnet Mask |
|---|---|
| `/24` | `255.255.255.0` |
| `/23` | `255.255.254.0` |
| `/22` | `255.255.252.0` |
| `/16` | `255.255.0.0` |
| `/8`  | `255.0.0.0` |

## Example Output

```
[2024-03-15 10:22:01] Current IP address : 192.168.1.42
[2024-03-15 10:22:01] New IP address     : 172.30.50.42 (subnet 172.30.50.0/23, mask 255.255.254.0)
[2024-03-15 10:22:01] DNS servers        : 8.8.8.8, 8.8.4.4
[2024-03-15 10:22:02] IP address successfully changed from 192.168.1.42 to 172.30.50.42.
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
