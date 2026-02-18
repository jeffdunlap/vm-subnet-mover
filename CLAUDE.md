# CLAUDE.md — AI Assistant Guide for vm-subnet-mover

## Project Overview

`vm-subnet-mover` is a PowerShell script project that helps move VMs (and other networked devices) to a new subnet. The script preserves the last octet of a device's current IP address and reassigns the first three octets to match the destination subnet.

This project is in early development. The main script file exists but is currently empty.

## Repository Structure

```
vm-subnet-mover/
├── CLAUDE.md             # This file — AI assistant guide
├── README.md             # Project documentation (to be completed)
├── TODO.md               # Planned features and task tracking
├── vm-subnet-mover.ps1   # Main PowerShell script (to be implemented)
└── .gitignore            # Ignores IntelliJ project files
```

## Development Status

The project is in early scaffolding. All items below are tracked in `TODO.md` and remain incomplete:

- [ ] Build a comprehensive `README.md`
- [ ] Build `vm-subnet-mover.ps1` (note: `TODO.md` refers to this as `vm-subnet-move.ps1` — the actual file in the repo is `vm-subnet-mover.ps1`)
  - [ ] Accept a parameter for the subnet to move devices to
  - [ ] Accept a parameter for the subnet mask used on the destination network
  - [ ] Log the current IP address and what it is changing to
  - [ ] Keep the current last octet of the IP address and change the first three octets to the new subnet
- [ ] Build unit tests for the script using Pester

## Planned Script Behavior

The script (`vm-subnet-mover.ps1`) is planned to:

1. Accept a parameter for the **destination subnet** to move devices to (e.g., `192.168.10`)
2. Accept a parameter for the **subnet mask** used on the destination network (e.g., `255.255.255.0`)
3. Identify and log the device's **current IP address**
4. Compute the **new IP address** by replacing the first three octets with the destination subnet prefix while keeping the last octet unchanged
5. Apply the new IP configuration
6. Log what the IP address is **changing to**

## Conventions

### PowerShell Style

- Use `Param()` blocks at the top of scripts for named parameters with type annotations
- Use `[CmdletBinding()]` to support common parameters like `-Verbose` and `-WhatIf`
- Name parameters descriptively: `-DestinationSubnet`, `-SubnetMask`
- Use `Write-Verbose` for informational logging, `Write-Host` sparingly
- Follow PowerShell verb-noun naming for functions (e.g., `Get-CurrentIPAddress`, `Set-NewIPAddress`)
- Use `try/catch` blocks for error handling around network adapter operations
- Test on Windows environments with appropriate administrator privileges

### Testing with Pester

- Unit tests should be placed in a `tests/` directory (to be created)
- Test files should be named `*.Tests.ps1` (e.g., `vm-subnet-mover.Tests.ps1`)
- Use Pester v5+ syntax (`Describe`, `It`, `Should -Be`, `BeExactly`, etc.)
- Mock external calls (e.g., `Get-NetIPAddress`, `Set-NetIPAddress`) using `Mock`
- Run tests with: `Invoke-Pester ./tests/`

### Git Conventions

- Commit messages should be clear and descriptive
- Development work is done on feature branches prefixed with `claude/`
- The main branch is `master`

## Key Workflows

### Running the Script (once implemented)

```powershell
# Move VMs to subnet 10.20.30.x with mask 255.255.255.0
.\vm-subnet-mover.ps1 -DestinationSubnet "10.20.30" -SubnetMask "255.255.255.0"
```

### Running Tests (once tests exist)

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester ./tests/
```

## Notes for AI Assistants

- The `vm-subnet-mover.ps1` file is **empty** — any implementation should be written from scratch following the planned requirements in `TODO.md`
- `TODO.md` refers to the script as `vm-subnet-move.ps1` (missing trailing `r`); the actual file on disk is `vm-subnet-mover.ps1` — use the actual filename
- The script targets **devices** broadly (not just VMs); the phrasing "move devices to" in `TODO.md` is intentional
- Subnet manipulation logic: preserve the last octet (e.g., `.45`) and prepend the new three-octet prefix (e.g., `10.20.30`) to form the new IP
- Logging must capture: the current IP address **and** the new IP address it is changing to — per `TODO.md` requirement
- The script operates on Windows; network adapter cmdlets like `Get-NetIPAddress` and `Set-NetIPAddress` are the relevant PowerShell native APIs
- `README.md` is empty and should be written once the script implementation is defined
