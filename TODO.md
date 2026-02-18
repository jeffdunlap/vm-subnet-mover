# vm-subnet-mover

This is a Powershell script to help moving VMs to a new

## TODO

## In Progress

## Done
*   [x] Build a comprehensive README.md
*   [x] Build vm-subnet-mover.ps1
  *    [x] Script should accept a parameter for the subnet to move devices to
  *    [x] Script should accept a parameter for the subnet mask used on the destination network
  *    [x] Script should have logging to identify its current IP address and what it is changing to
  *    [x] Script should keep the current last octet of its IP address and change the first three octets to the new subnet
  *    [x] Script should accept a parameter for two DNS server IP addresses (comma-separated)
*    [x] Build unit tests for script using pester

## Backlog
