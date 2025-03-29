param(
    [Parameter(Mandatory=$true)]
    [string]$MerakiAuthToken,
    
    [Parameter(Mandatory=$true)]
    [string]$PRTGServer,
    
    [Parameter(Mandatory=$true)]
    [string]$PRTGUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$PRTGPasshash,
    
    [Parameter(Mandatory=$true)]
    [int]$PRTGDeviceId
)

# Import required modules
Import-Module Meraki, PrtgAPI

# Set up logging
$logFile = "MerakiPRTGSensorCreator_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Error handling function
function Handle-Error {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    $errorMessage = "Error: $($ErrorRecord.Exception.Message)"
    $errorDetails = "Details: $($ErrorRecord.ScriptStackTrace)"
    Write-Log $errorMessage
    Write-Log $errorDetails
    Write-Host "An error occurred. Please check the log file: $logFile" -ForegroundColor Red
}

# Function to perform API call with retry logic
function Invoke-WithRetry {
    param (
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 5,
        [int]$InitialDelay = 2
    )
    $attempt = 1
    $delay = $InitialDelay
    while ($attempt -le $MaxAttempts) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -eq $MaxAttempts) { throw }
            Write-Log "Attempt $attempt failed: $($_.Exception.Message). Retrying in $delay seconds."
            Start-Sleep -Seconds $delay
            $attempt++
            $delay *= 2  # Exponential backoff
        }
    }
}

# Function to prompt user for selection
function Get-UserSelection {
    param (
        [array]$Items,
        [string]$Prompt,
        [switch]$AllowMultiple
    )
    Write-Host $Prompt
    $Items | ForEach-Object { $i = 0 } { Write-Host "[$i] $($_.name) (ID: $($_.id))"; $i++ }
    if ($AllowMultiple) {
        Write-Host "[A] All items"
        Write-Host "To select multiple items, enter numbers separated by commas (e.g., 0,2,5)"
    }
    do {
        $input = Read-Host "Enter your selection"
        if ($AllowMultiple -and $input -eq "A") {
            Write-Log "User selected all items"
            return $Items
        }
        if ($AllowMultiple) {
            $selectedIndices = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
            if ($selectedIndices.Count -gt 0 -and ($selectedIndices | ForEach-Object { [int]$_ -ge 0 -and [int]$_ -lt $Items.Count })) {
                $selectedItems = $selectedIndices | ForEach-Object { $Items[[int]$_] }
                Write-Log ("User selected items: {0}" -f ($selectedItems.name -join ", "))
                return $selectedItems
            }
        } else {
            $selectedIndex = 0
            if ([int]::TryParse($input, [ref]$selectedIndex) -and $selectedIndex -ge 0 -and $selectedIndex -lt $Items.Count) {
                Write-Log ("User selected item {0}: {1}" -f $selectedIndex, $Items[$selectedIndex].name)
                return $Items[$selectedIndex]
            }
        }
        Write-Log ("Invalid selection: {0}" -f $input)
        Write-Host "Invalid selection. Please try again."
    } while ($true)
}

# Function to check if a device is an active Meraki MX (firewall)
function Is-ActiveMerakiMX {
    param ([PSObject]$Device)
    return $Device.model -like "MX*"
}

# Function to check if a device is active
function Is-ActiveDevice {
    param (
        [string]$AuthToken,
        [string]$DeviceSerial
    )
    try {
        $performance = Invoke-WithRetry { 
            Get-MerakiDeviceAppliancePerformance -AuthToken $AuthToken -DeviceSerial $DeviceSerial 
        }
        return $null -ne $performance -and $performance.perfScore -ge 0
    }
    catch {
        Write-Log "Error checking device activity for $DeviceSerial. This may be a spare device or there might be an API issue."
        return $false
    }
}

# Function to create a PRTG sensor
function New-PRTGSensor {
    param (
        [PSObject]$MerakiDevice,
        [int]$DeviceId,
        [string]$NetworkName,
        [string]$AuthToken
    )
    try {
        if (-not (Is-ActiveDevice -AuthToken $AuthToken -DeviceSerial $MerakiDevice.serial)) {
            Write-Log "Device $($MerakiDevice.serial) is not active. Skipping sensor creation."
            return $false
        }

        $sensorName = "$NetworkName - $($MerakiDevice.model) Performance - $($MerakiDevice.name)"
        Write-Log "Creating PRTG sensor for active Meraki MX device $($MerakiDevice.serial) on PRTG device $DeviceId"
                
        $prtgDevice = Get-Device -Id $DeviceId
        $params = $prtgDevice | New-SensorParameters -RawType exexml
        $params.Unlock()
        $params["name_"] = $sensorName
        $params["exefile_"] = "MerakiDevicePerformance.ps1"
        $params["exeparams"] = "-AuthToken '$MerakiAuthToken' -DeviceSerial '$($MerakiDevice.serial)'"
        $params["mutex_"] = "MerakiDevicePerformance_$($MerakiDevice.serial)"
        $params["tags_"] = "meraki performance mx $NetworkName"
        $params["priority_"] = 3
        $params["environment"] = 0
        $params["usewindowsauthentication"] = 0
        $params["writeresult"] = 1
        $params.Lock()
        $newSensor = $prtgDevice | Add-Sensor $params
        if ($newSensor) {
            Write-Log "Sensor created. Sensor ID: $($newSensor.Id)"
            if ($newSensor.Status -eq "Paused") {
                Write-Log "Sensor is paused. Attempting to resume..."
                $newSensor | Resume-Object
                Write-Log "Sensor resumed."
            }
            $updatedSensor = Get-Sensor -Id $newSensor.Id
            Write-Log "Sensor parameters after creation: $($updatedSensor.Parameters)"
            Write-Log "Successfully created PRTG sensor for Meraki MX device $($MerakiDevice.serial)"
            return $true
        } else {
            Write-Log "Failed to create sensor for Meraki MX device $($MerakiDevice.serial)"
            return $false
        }
    }
    catch {
        Handle-Error $_
        return $false
    }
}

# Main script execution
try {
    Write-Log "Script started"
    Connect-PrtgServer $PRTGServer (New-Credential -Username $PRTGUsername -Password $PRTGPasshash)
    Write-Log "Connected to PRTG Server"
    $organizations = Invoke-WithRetry { Get-MerakiOrganizations -AuthToken $MerakiAuthToken }
    Write-Log ("Successfully fetched {0} organizations" -f $organizations.Count)
    $selectedOrg = Get-UserSelection -Items $organizations -Prompt "Available Meraki Organizations:"
    Write-Log ("Selected organization: {0}" -f $selectedOrg.name)
    $networks = Invoke-WithRetry { Get-MerakiOrganizationNetworks -AuthToken $MerakiAuthToken -OrganizationId $selectedOrg.id }
    Write-Log ("Successfully fetched {0} networks" -f $networks.Count)
    $selectedNetworks = Get-UserSelection -Items $networks -Prompt ("Available Networks in {0}:" -f $selectedOrg.name) -AllowMultiple
    
    foreach ($selectedNetwork in $selectedNetworks) {
        Write-Log ("Processing network: {0}" -f $selectedNetwork.name)
        $devices = Invoke-WithRetry { Get-MerakiNetworkDevices -AuthToken $MerakiAuthToken -NetworkId $selectedNetwork.id }
        $mxDevices = $devices | Where-Object { Is-ActiveMerakiMX -Device $_ }
        Write-Log ("Fetched {0} devices: {1} MX devices" -f $devices.Count, ($mxDevices | Measure-Object).Count)
        
        foreach ($device in $mxDevices) {
            $result = Invoke-WithRetry { 
                New-PRTGSensor -MerakiDevice $device -DeviceId $PRTGDeviceId -NetworkName $selectedNetwork.name -AuthToken $MerakiAuthToken 
            }
            if ($result) {
                $logMessage = "Successfully created"
            } else {
                $logMessage = "Skipped or failed to create"
            }
            Write-Log ("$logMessage sensor for {0} (Serial: {1}) on PRTG device {2}" -f $device.name, $device.serial, $PRTGDeviceId)
        }
    }
    Write-Log "Sensor creation process completed for all selected networks."
}
catch {
    Handle-Error $_
}
finally {
    Write-Log "Script execution finished"
    Disconnect-PrtgServer
}

Write-Host "Script execution completed. For detailed information, please check the log file: $logFile"
