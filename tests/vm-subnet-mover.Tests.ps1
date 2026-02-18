BeforeAll {
    $scriptPath = "$PSScriptRoot/../vm-subnet-mover.ps1"
}

Describe "Test-ValidIPv4" {
    BeforeAll {
        # Dot-source only the helper functions from the script
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

Describe "Convert-MaskToPrefixLength" {
    BeforeAll {
        . {
            function Convert-MaskToPrefixLength {
                param([string]$Mask)
                $binary = ($Mask -split '\.' | ForEach-Object { [Convert]::ToString([int]$_, 2).PadLeft(8, '0') }) -join ''
                return ($binary.ToCharArray() | Where-Object { $_ -eq '1' }).Count
            }
        }
    }

    It "converts 255.255.255.0 to 24" {
        Convert-MaskToPrefixLength -Mask "255.255.255.0" | Should -Be 24
    }

    It "converts 255.255.0.0 to 16" {
        Convert-MaskToPrefixLength -Mask "255.255.0.0" | Should -Be 16
    }

    It "converts 255.0.0.0 to 8" {
        Convert-MaskToPrefixLength -Mask "255.0.0.0" | Should -Be 8
    }

    It "converts 255.255.255.128 to 25" {
        Convert-MaskToPrefixLength -Mask "255.255.255.128" | Should -Be 25
    }
}

Describe "IP address computation" {
    It "builds the new IP by combining the destination subnet with the last octet" {
        $destinationSubnet = "10.20.30"
        $currentIP         = "192.168.1.45"
        $lastOctet         = ($currentIP -split '\.')[-1]
        $newIP             = "$destinationSubnet.$lastOctet"
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
}

Describe "Parameter validation: DestinationSubnet" {
    It "rejects a subnet with fewer than three octets" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168" -SubnetMask "255.255.255.0" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects a subnet with four octets" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.1.0" -SubnetMask "255.255.255.0" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects a subnet with an out-of-range octet" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "999.168.1" -SubnetMask "255.255.255.0" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

Describe "Parameter validation: SubnetMask" {
    It "rejects a mask with an invalid octet" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10" -SubnetMask "255.255.300.0" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects a non-dotted-decimal mask" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10" -SubnetMask "not-a-mask" -DnsServers "8.8.8.8,8.8.4.4"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }
}

Describe "Parameter validation: DnsServers" {
    It "rejects a single DNS server" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10" -SubnetMask "255.255.255.0" -DnsServers "8.8.8.8"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects three DNS servers" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10" -SubnetMask "255.255.255.0" -DnsServers "8.8.8.8,8.8.4.4,1.1.1.1"
        } -args "$PSScriptRoot/../vm-subnet-mover.ps1" 2>&1
        $LASTEXITCODE | Should -Be 1
    }

    It "rejects an invalid DNS IP address" {
        $result = & pwsh -NoProfile -NonInteractive -Command {
            & "$args" -DestinationSubnet "192.168.10" -SubnetMask "255.255.255.0" -DnsServers "8.8.8.8,not-an-ip"
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

    It "calls New-NetIPAddress with the correct new IP" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30" `
            -SubnetMask "255.255.255.0" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke New-NetIPAddress -Times 1 -ParameterFilter {
            $IPAddress -eq "10.20.30.50"
        }
    }

    It "calls New-NetIPAddress with the correct prefix length" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30" `
            -SubnetMask "255.255.255.0" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke New-NetIPAddress -Times 1 -ParameterFilter {
            $PrefixLength -eq 24
        }
    }

    It "calls Set-DnsClientServerAddress with both DNS servers" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30" `
            -SubnetMask "255.255.255.0" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke Set-DnsClientServerAddress -Times 1 -ParameterFilter {
            $ServerAddresses -contains "8.8.8.8" -and $ServerAddresses -contains "8.8.4.4"
        }
    }

    It "calls Remove-NetIPAddress before applying the new IP" {
        & "$PSScriptRoot/../vm-subnet-mover.ps1" `
            -DestinationSubnet "10.20.30" `
            -SubnetMask "255.255.255.0" `
            -DnsServers "8.8.8.8,8.8.4.4"

        Should -Invoke Remove-NetIPAddress -Times 1
    }
}
