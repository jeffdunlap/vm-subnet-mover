BeforeAll {
    $scriptPath = "$PSScriptRoot/../vm-subnet-mover.ps1"
}

Describe "Test-ValidIPv4" {
    BeforeAll {
        . {
            function Test-ValidIPv4 {
                param([string]$Address)
                if ($Address -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { return $false }
                $octets = $Address -split '\.'
                foreach ($octet in $octets) {
                    if ([int]$octet -lt 0 -or [int]$octet -gt 255) { return $false }
                }
                return $true
            }
        }
    }

    It "returns true for a valid IPv4 address" {
        Test-ValidIPv4 -Address "192.168.1.100" | Should -BeTrue
    }

    It "returns true for all-zero address" {
        Test-ValidIPv4 -Address "0.0.0.0" | Should -BeTrue
    }

    It "returns false for an address with an octet above 255" {
        Test-ValidIPv4 -Address "192.168.1.256" | Should -BeFalse
    }

    It "returns false for a non-numeric address" {
        Test-ValidIPv4 -Address "not-an-ip" | Should -BeFalse
    }

    It "returns false for only three octets" {
        Test-ValidIPv4 -Address "192.168.1" | Should -BeFalse
    }

    It "returns false for five octets" {
        Test-ValidIPv4 -Address "192.168.1.1.1" | Should -BeFalse
    }
}

Describe "Convert-PrefixLengthToMask" {
    BeforeAll {
        . {
            function Convert-PrefixLengthToMask {
                param([int]$PrefixLength)
                $binary = '1' * $PrefixLength + '0' * (32 - $PrefixLength)
                $octets = for ($i = 0; $i -lt 32; $i += 8) {
                    [Convert]::ToInt32($binary.Substring($i, 8), 2)
                }
                return $octets -join '.'
            }
        }
    }

    It "converts /24 to 255.255.255.0" {
        Convert-PrefixLengthToMask -PrefixLength 24 | Should -Be "255.255.255.0"
    }

    It "converts /16 to 255.255.0.0" {
        Convert-PrefixLengthToMask -PrefixLength 16 | Should -Be "255.255.0.0"
    }

    It "converts /8 to 255.0.0.0" {
        Convert-PrefixLengthToMask -PrefixLength 8 | Should -Be "255.0.0.0"
    }

    It "converts /23 to 255.255.254.0" {
        Convert-PrefixLengthToMask -PrefixLength 23 | Should -Be "255.255.254.0"
    }

    It "converts /25 to 255.255.255.128" {
        Convert-PrefixLengthToMask -PrefixLength 25 | Should -Be "255.255.255.128"
    }

    It "converts /32 to 255.255.255.255" {
        Convert-PrefixLengthToMask -PrefixLength 32 | Should -Be "255.255.255.255"
    }

    It "converts /0 to 0.0.0.0" {
        Convert-PrefixLengthToMask -PrefixLength 0 | Should -Be "0.0.0.0"
    }
}

Describe "ConvertFrom-CIDR" {
    BeforeAll {
        . {
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
        }
    }

    It "parses a /24 CIDR and derives the correct mask" {
        $result = ConvertFrom-CIDR -CIDR "192.168.10.0/24"
        $result.SubnetMask | Should -Be "255.255.255.0"
    }

    It "parses a /23 CIDR and derives the correct mask" {
        $result = ConvertFrom-CIDR -CIDR "172.30.50.0/23"
        $result.SubnetMask | Should -Be "255.255.254.0"
    }

    It "parses a /16 CIDR and derives the correct mask" {
        $result = ConvertFrom-CIDR -CIDR "10.20.0.0/16"
        $result.SubnetMask | Should -Be "255.255.0.0"
    }

    It "extracts the correct prefix length" {
        $result = ConvertFrom-CIDR -CIDR "172.30.50.0/23"
        $result.PrefixLength | Should -Be 23
    }

    It "extracts the correct network address" {
        $result = ConvertFrom-CIDR -CIDR "172.30.50.0/23"
        $result.NetworkAddress | Should -Be "172.30.50.0"
    }

    It "extracts the correct three-octet subnet prefix" {
        $result = ConvertFrom-CIDR -CIDR "172.30.50.0/23"
        $result.SubnetPrefix | Should -Be "172.30.50"
    }

    It "returns null for input without a slash" {
        ConvertFrom-CIDR -CIDR "192.168.10.0" | Should -BeNullOrEmpty
    }

    It "returns null for input with only three octets before the slash" {
        ConvertFrom-CIDR -CIDR "192.168.10/24" | Should -BeNullOrEmpty
    }

    It "returns null for a prefix length above 32" {
        ConvertFrom-CIDR -CIDR "192.168.10.0/33" | Should -BeNullOrEmpty
    }

    It "returns null for an invalid network address octet" {
        ConvertFrom-CIDR -CIDR "999.168.10.0/24" | Should -BeNullOrEmpty
    }
}

Describe "IP address computation" {
    It "builds the new IP by combining the CIDR subnet prefix with the last octet" {
        $cidrPrefix = "10.20.30"
        $currentIP  = "192.168.1.45"
        $lastOctet  = ($currentIP -split '\.')[-1]
        $newIP      = "$cidrPrefix.$lastOctet"
        $newIP | Should -Be "10.20.30.45"
    }

    It "preserves last octet 1" {
        $lastOctet = ("192.168.0.1" -split '\.')[-1]
        "10.0.0.$lastOctet" | Should -Be "10.0.0.1"
    }

    It "preserves last octet 254" {
        $lastOctet = ("172.16.5.254" -split '\.')[-1]
        "10.0.0.$lastOctet" | Should -Be "10.0.0.254"
    }

    It "uses the first three octets of the CIDR network address as the prefix" {
        $result = @{ SubnetPrefix = "172.30.50" }
        $lastOctet = ("192.168.1.77" -split '\.')[-1]
        "$($result.SubnetPrefix).$lastOctet" | Should -Be "172.30.50.77"
    }
}

Describe "Parameter validation: DestinationSubnet CIDR" {
    It "rejects input with no slash" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10.0" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects input with only three octets before the slash" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10/24" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects a prefix length above 32" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10.0/33" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects a CIDR with an out-of-range network octet" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "999.168.10.0/24" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

Describe "Parameter validation: DnsServers" {
    It "rejects a single DNS server" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10.0/24" -DnsServers "8.8.8.8"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects three DNS servers" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10.0/24" -DnsServers "8.8.8.8,8.8.4.4,1.1.1.1"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects an invalid DNS IP address" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10.0/24" -DnsServers "8.8.8.8,not-an-ip"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "parses two valid DNS IPs into an array of two elements" {
        $dnsArray = "8.8.8.8,8.8.4.4" -split ',' | ForEach-Object { $_.Trim() }
        $dnsArray.Count | Should -Be 2
        $dnsArray[0]    | Should -Be "8.8.8.8"
        $dnsArray[1]    | Should -Be "8.8.4.4"
    }

    It "handles whitespace around comma in DNS input" {
        $dnsArray = "8.8.8.8 , 8.8.4.4" -split ',' | ForEach-Object { $_.Trim() }
        $dnsArray.Count | Should -Be 2
        $dnsArray[0]    | Should -Be "8.8.8.8"
        $dnsArray[1]    | Should -Be "8.8.4.4"
    }
}

Describe "Network change operations" {
    BeforeAll {
        Mock Get-NetIPAddress {
            [PSCustomObject]@{
                IPAddress      = "192.168.1.50"
                InterfaceIndex = 5
                AddressFamily  = "IPv4"
                PrefixOrigin   = "Manual"
            }
        }
        Mock Remove-NetIPAddress {}
        Mock New-NetIPAddress {}
        Mock Set-DnsClientServerAddress {}
        Mock Write-Host {}
    }

    It "calls New-NetIPAddress with the correct new IP derived from CIDR" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30.0/24" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke New-NetIPAddress -Times 1 -ParameterFilter {
            $IPAddress -eq "10.20.30.50"
        }
    }

    It "calls New-NetIPAddress with the prefix length parsed from the CIDR" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30.0/24" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke New-NetIPAddress -Times 1 -ParameterFilter {
            $PrefixLength -eq 24
        }
    }

    It "uses the correct prefix length for a non-/24 CIDR (/23)" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "172.30.50.0/23" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke New-NetIPAddress -Times 1 -ParameterFilter {
            $PrefixLength -eq 23
        }
    }

    It "calls Set-DnsClientServerAddress with both DNS servers" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30.0/24" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke Set-DnsClientServerAddress -Times 1 -ParameterFilter {
            $ServerAddresses -contains "8.8.8.8" -and $ServerAddresses -contains "8.8.4.4"
        }
    }

    It "calls Remove-NetIPAddress before applying the new IP" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30.0/24" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke Remove-NetIPAddress -Times 1
    }
}
