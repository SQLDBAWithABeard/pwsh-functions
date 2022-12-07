# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
$Message =  "TIME: {0} PowerShell timer trigger function is starting " -f $currentUTCtime
Write-Host $Message

Import-Module smartmeter
Import-Module PSFramework
Import-Module dbatools

Invoke-MeterDataLoad -DontRunRefresh -verbose

## $Modules = Get-Module -ListAvailable 
## 
## $Message = "The following modules are available:
## {0}" -f ($Modules | Format-Table -AutoSize | Out-String)
## Write-Host $Message