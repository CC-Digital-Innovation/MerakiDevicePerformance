# Meraki Device Utilization PRTG Sensor

## Overview
This PowerShell script creates a custom PRTG sensor that monitors the device utilization of Meraki appliances using the Meraki API. It retrieves the device utilization percentage and sets appropriate warning and error states based on configurable thresholds.

## Features
- Retrieves device utilization data from the Meraki API
- Configurable warning and error thresholds
- Outputs results in PRTG-compatible format
- Supports multiple devices through PRTG's device-specific credentials

## Prerequisites
- PowerShell 5.1 or later
- Meraki PowerShell module installed on the PRTG probe server
- Meraki API key with read access to the target devices
- PRTG Network Monitor

## Installation
1. Install the Meraki PowerShell module on your PRTG probe server:
   ```powershell
   Install-Module -Name Meraki -Force
   ```
2. Save the script file (e.g., `MerakiDeviceUtilization.ps1`) on your PRTG probe server.

## Usage
To use this script as a PRTG sensor:

1. In PRTG, add a new sensor to your device and choose "EXE/Script Advanced" sensor type.
2. Set the sensor to use PowerShell as the EXE/Script.
3. In the "Parameters" field, enter: `-AuthToken "AUTHTOKEN" -DeviceSerial "SERIALNUMBER"`
4. In your device settings, set the Windows credentials:
   - Username: Your Meraki API key
   - Domain/PDC: Your device serial number

## Parameters
- `AuthToken`: The API key for accessing the Meraki API.
- `DeviceSerial`: The serial number of the Meraki device to monitor.

## Outputs
This script outputs PRTG sensor results with the following information:
- Channel: Device Utilization
- Value: Current utilization percentage
- Unit: Percent
- Status: OK, WARNING, or ERROR based on thresholds

## Customization
You can adjust the warning and error thresholds by modifying the following lines in the script:
```powershell
$warningThreshold = 75
$errorThreshold = 90
```

## Notes
- Author: Richard Travellin
- Date: 8/14/2024
- Version: 1.0
- Link: https://github.com/CC-Digital-Innovation/MerakiDevicePerformance

## License
MIT

## Contributing
Contributions to this project are welcome. Please fork the repository and submit a pull request with your changes.

## Support
For support, please open an issue in the GitHub repository or contact Richard Travellin
