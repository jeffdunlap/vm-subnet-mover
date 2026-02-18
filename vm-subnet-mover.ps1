[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationSubnet,

    [Parameter(Mandatory = $true)]
    [string]$SubnetMask,

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

function Convert-MaskToPrefixLength {
    param([string]$Mask)
    $binary = ($Mask -split '\.' | ForEach-Object { [Convert]::ToString([int]$_, 2).PadLeft(8, '0') }) -join ''
    return ($binary.ToCharArray() | Where-Object { $_ -eq '1' }).Count
}

# --- Validate DestinationSubnet ---
$subnetOctets = $DestinationSubnet -split '\.'
if ($subnetOctets.Count -ne 3) {
    Write-Log "ERROR: DestinationSubnet '$DestinationSubnet' must contain exactly three octets (e.g. '192.168.10')."
    exit 1
}
foreach ($octet in $subnetOctets) {
    if ($octet -notmatch '^\d+$' -or [int]$octet -lt 0 -or [int]$octet -gt 255) {
        Write-Log "ERROR: DestinationSubnet '$DestinationSubnet' contains an invalid octet '$octet'."
        exit 1
    }
}

# --- Validate SubnetMask ---
if (-not (Test-ValidIPv4 -Address $SubnetMask)) {
    Write-Log "ERROR: SubnetMask '$SubnetMask' is not a valid dotted-decimal mask (e.g. '255.255.255.0')."
    exit 1
}
$prefixLength = Convert-MaskToPrefixLength -Mask $SubnetMask

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

$currentIP   = $ipInfo.IPAddress
$lastOctet   = ($currentIP -split '\.')[-1]
$newIP       = "$DestinationSubnet.$lastOctet"
$adapterIndex = $ipInfo.InterfaceIndex

Write-Log "Current IP address : $currentIP"
Write-Log "New IP address     : $newIP (subnet $DestinationSubnet, mask $SubnetMask)"
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
