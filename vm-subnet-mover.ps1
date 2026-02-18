[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationSubnet,

    [Parameter(Mandatory = $true)]
    [string]$DnsServers
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

function Test-ValidIPv4 {
    param([string]$Address)
    if ($Address -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { return $false }
    $octets = $Address -split '\.'
    foreach ($octet in $octets) {
        if ([int]$octet -lt 0 -or [int]$octet -gt 255) { return $false }
    }
    return $true
}

function Convert-PrefixLengthToMask {
    param([int]$PrefixLength)
    $binary = '1' * $PrefixLength + '0' * (32 - $PrefixLength)
    $octets = for ($i = 0; $i -lt 32; $i += 8) {
        [Convert]::ToInt32($binary.Substring($i, 8), 2)
    }
    return $octets -join '.'
}

function ConvertFrom-CIDR {
    param([string]$CIDR)
    if ($CIDR -notmatch '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/(\d{1,2})$') { return $null }

    $networkAddress = $Matches[1]
    $prefixLength   = [int]$Matches[2]

    if (-not (Test-ValidIPv4 -Address $networkAddress)) { return $null }
    if ($prefixLength -lt 0 -or $prefixLength -gt 32)   { return $null }

    $subnetMask   = Convert-PrefixLengthToMask -PrefixLength $prefixLength
    $subnetOctets = $networkAddress -split '\.'
    $subnetPrefix = "$($subnetOctets[0]).$($subnetOctets[1]).$($subnetOctets[2])"

    return @{
        NetworkAddress = $networkAddress
        PrefixLength   = $prefixLength
        SubnetMask     = $subnetMask
        SubnetPrefix   = $subnetPrefix
    }
}

# --- Validate DestinationSubnet (CIDR notation) ---
$cidrInfo = ConvertFrom-CIDR -CIDR $DestinationSubnet
if ($null -eq $cidrInfo) {
    Write-Log "ERROR: DestinationSubnet '$DestinationSubnet' is not valid CIDR notation (e.g. '172.30.50.0/23')."
    exit 1
}

$subnetPrefix = $cidrInfo.SubnetPrefix
$subnetMask   = $cidrInfo.SubnetMask
$prefixLength = $cidrInfo.PrefixLength

# --- Validate DnsServers ---
$dnsArray = $DnsServers -split ',' | ForEach-Object { $_.Trim() }
if ($dnsArray.Count -ne 2) {
    Write-Log "ERROR: DnsServers must contain exactly two comma-separated IP addresses. Got $($dnsArray.Count)."
    exit 1
}
foreach ($dns in $dnsArray) {
    if (-not (Test-ValidIPv4 -Address $dns)) {
        Write-Log "ERROR: DNS server address '$dns' is not a valid IPv4 address."
        exit 1
    }
}

# --- Detect current IP address ---
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -First 1

if ($null -eq $ipInfo) {
    Write-Log "ERROR: No usable IPv4 address found on this machine."
    exit 1
}

$currentIP    = $ipInfo.IPAddress
$lastOctet    = ($currentIP -split '\.')[-1]
$newIP        = "$subnetPrefix.$lastOctet"
$adapterIndex = $ipInfo.InterfaceIndex

Write-Log "Current IP address : $currentIP"
Write-Log "New IP address     : $newIP (subnet $DestinationSubnet, mask $subnetMask)"
Write-Log "DNS servers        : $($dnsArray -join ', ')"

# --- Apply changes ---
if ($PSCmdlet.ShouldProcess($currentIP, "Change IP to $newIP and set DNS to $($dnsArray -join ', ')")) {
    try {
        Remove-NetIPAddress -InterfaceIndex $adapterIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction Stop
        New-NetIPAddress -InterfaceIndex $adapterIndex -IPAddress $newIP -PrefixLength $prefixLength -ErrorAction Stop | Out-Null
        Write-Log "IP address successfully changed from $currentIP to $newIP."
    }
    catch {
        Write-Log "ERROR: Failed to update IP address. $_"
        exit 1
    }

    try {
        Set-DnsClientServerAddress -InterfaceIndex $adapterIndex -ServerAddresses $dnsArray -ErrorAction Stop
        Write-Log "DNS servers successfully set to $($dnsArray -join ', ')."
    }
    catch {
        Write-Log "ERROR: Failed to set DNS servers. $_"
        exit 1
    }
}
