<#
.SYNOPSIS
Monitors device utilization for Meraki appliances and outputs the results to PRTG.

.DESCRIPTION
This script retrieves device utilization information from the Meraki API for a specific device. It then outputs a PRTG sensor result with the utilization percentage and appropriate status (OK, WARNING, or ERROR) based on configurable thresholds.

.PARAMETER AuthToken
The API key for accessing the Meraki API.

.PARAMETER DeviceSerial
The serial number of the Meraki device to monitor.

.INPUTS
None.

.OUTPUTS
Outputs PRTG sensor results with information on the device utilization for the specified Meraki appliance.

.NOTES
Author: Richard Travellin
Date: 8/14/2024
Version: 1.0

.LINK
https://github.com/CC-Digital-Innovation/MerakiDevicePerformance

.EXAMPLE
./MerakiDeviceUtilization.ps1 -AuthToken "YOUR_API_KEY" -DeviceSerial "DEVICE_SERIAL_NUMBER"
This example runs the script to check the device utilization for the specified Meraki appliance using the provided API key and device serial number.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AuthToken,
    
    [Parameter(Mandatory=$true)]
    [string]$DeviceSerial
)

# Import the Meraki PowerShell module
# Make sure it's installed: Install-Module -Name Meraki -Force
# Comment out to speed up script
# Import-Module Meraki

# Get the device utilization
try {
    $performance = Get-MerakiDeviceAppliancePerformance -AuthToken $AuthToken -DeviceSerial $DeviceSerial
    $utilization = [double]$performance.perfScore
}
catch {
    Write-Host "Error fetching device utilization: $_"
    exit 2  # PRTG error state
}

# Define thresholds (as percentages)
$warningThreshold = 75
$errorThreshold = 90

# Determine the status based on thresholds
if ($utilization -ge $errorThreshold) {
    $status = 2  # Error
    $statusText = "ERROR"
} elseif ($utilization -ge $warningThreshold) {
    $status = 1  # Warning
    $statusText = "WARNING"
} else {
    $status = 0  # OK
    $statusText = "OK"
}

# Output in PRTG format
Write-Host "<prtg>"
Write-Host "<result>"
Write-Host "<channel>Device Utilization</channel>"
Write-Host "<value>$($utilization.ToString('0.0'))</value>"
Write-Host "<float>1</float>"
Write-Host "<unit>Percent</unit>"
Write-Host "<limitmode>1</limitmode>"
Write-Host "<limitmaxwarning>$warningThreshold</limitmaxwarning>"
Write-Host "<limitmaxerror>$errorThreshold</limitmaxerror>"
Write-Host "</result>"
Write-Host "<text>Device Utilization: $($utilization.ToString('0.0'))% ($statusText)</text>"
Write-Host "</prtg>"

exit $status