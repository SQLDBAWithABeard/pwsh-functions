# Module for connecting to the Bright Smart meter api and loading data to database or for use in Universal Dashboard.
# Set up an account in the Bright App and connect your meter by adding your MPAN to the app and then once you can see data in the app this will work
# expects a secret called bright_password stored in secret management secret vault for the token otherwise pass in plain text (I know - but its used to get the token and not for anything else)
# You dont need to - but you can load to the database and use the PowerBi.
# The advantage of this is that you will be able to see historical 30 Minute data as you keep loading it. The App only keeps it for 10 days.
# The other advantage is that you can use the Excel Sheet stored in OneDrive to identify when things happen - Oven on - shower etc etc so that you can match the activity to the time that it happens.
# Alternatively you can use the UD script to run a universal dashboard webpage. I have done this using a docker container running in Azure Container Instances and fed from a different git repo. It isnt optimised though and fails the wife performance acceptance test as it makes too many API calls!! and also does not connect to the excel as that was a later thought. I am working on a better way to do this. 
# TODO load excel data into database and use that for PowerBi
# TODO Connect Universal Dashboard to database to improve load times and see if the charts are good enough.

<#
.SYNOPSIS
Creates a new token for the Bright Smart meter API and stores it in the environment variable $env:Bright_Meter_Token

.DESCRIPTION
Creates a new token for the Bright Smart meter API and stores it in the environment variable $env:Bright_Meter_Token

.PARAMETER bright
The Bright App User Name

.PARAMETER password
The Bright App Password - by default uses a secret called bright_password stored in secret management secret vault for the token otherwise pass in plain text (I know - but its used to get the token and not for anything else)

.PARAMETER applicationid
The Bright App AppId - set to the default which should be fine

.EXAMPLE
Set-MeterToken -bright "BrightAppUser" -password "BrightAppPassword" -applicationid "BrightAppAppId"

The AI picked that example up and it worked.

.NOTES
Rob Sewell July 2022
#>
function Set-MeterToken {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        $bright = "mrrobsewell@outlook.com", # Your account username
        $password,
        $applicationid = 'b0f1b774-a586-4f72-9edd-27ead8aa7a8d'
    )


    # get a token
    $login = 'https://api.glowmarkt.com/api/v0-1/auth'
    $loginHeaders = @{
        "Content-Type"  = "application/json"
        "applicationId" = "$applicationid"
    }
    $login_body = @{
        "username" = "$bright"
        "password" = "$password"
    } | ConvertTo-Json

    $login_response = Invoke-RestMethod -Headers $loginHeaders -Method Post -Uri $login -Body $login_body 

    if ($PSCmdlet.ShouldProcess("Bright_Meter_Token Environmental variable" , "Sets the")) {
        $env:Bright_Meter_Token = $login_response.token
    }
}

<#
.SYNOPSIS
Gets a roll up of the data for a specific time period.

.DESCRIPTION
Gets a roll up of the data for a specific time period.

.PARAMETER resourceType
cost or consumption

.PARAMETER timePeriod
yesterday, today, thisweek, lastweek, month, lastmonth, year

.EXAMPLE
Get-MeterDataRollUp -resourceType cost -timePeriod lastweek 

Count             : 7
Average           : 557.544013714286       
Sum               : 3902.808096
Maximum           : 694.07692
Minimum           : 493.857336
StandardDeviation : 
Property          : pence

Gets the roll up data for last week

.NOTES
Rob Sewell July 2022
#>
function Get-MeterDataRollUp {
    [CmdletBinding()]
    param (

        [ValidateSet('consumption', 'cost')]
        $resourceType = 'consumption',
        [validateSet('yesterday', 'today', 'thisweek', 'lastweek', 'month', 'lastmonth', 'year')]
        $timePeriod 
    )

    switch ($resourceType) {
        consumption { 
            $results = Get-MeterData -resourceType consumption -timePeriod $timePeriod
            $results | Measure-Object -Property kwH -Sum -Average -Maximum -Minimum
        }
        cost {
            $results = Get-MeterData -resourceType cost -timePeriod $timePeriod
            $results | Measure-Object -Property pence -Sum -Average -Maximum -Minimum 
        }
        Default {}
    }
}

<#
.SYNOPSIS
Get todays data for the meter.

.DESCRIPTION
get todays data for the meter.

.EXAMPLE
Get-MeterToday

Gets todays meter data

.NOTES
Rob Sewell July 2022
#>
function Get-MeterToday {
    Get-MeterData consumption today
}

<#
.SYNOPSIS
Gets the raw meter data

.DESCRIPTION
Gets teh raw meter data for a specific resource type and time period.

.PARAMETER resourceType
cost or consumption

.PARAMETER timePeriod
yesterday, today, thisweek, lastweek, month, lastmonth, year

.PARAMETER offset
The offset from UTC defaults to +1

.PARAMETER function
The data roll up function defaults to sum

.PARAMETER token
The API toke - defaults to the environment variable $env:Bright_Meter_Token

.EXAMPLE
Get-MeterData -resourceType cost -timePeriod lastweek     

Date           pence
----           -----
Sunday    493.857336
Monday     694.07692
Tuesday    564.25236
Wednesday 528.657136
Thursday  543.571336
Friday     563.96828
Saturday  514.424728

Gets the raw cost data for last week

.NOTES
Rob Sewell July 2022
#>
function Get-MeterData {
    [CmdletBinding()]
    param (
        [ValidateSet('consumption', 'cost')]
        $resourceType, # sum, min, max, avg
        [ValidateSet('30Minute', 'hour', 'today', 'thisweek', 'lastweek', 'twoweeksago', 'threeweeksago', 'month', 'year', 'lastmonth', 'twomonthsago', 'yesterday')]
        $timePeriod = 'today' ,
        $offset = '-60' , # number of minutes offset from UTC - BST = -60
        $function = 'sum',
        [ValidateNotNullOrEmpty()]
        [string]$token = $env:Bright_Meter_Token
    )

    Write-PSFMessage "lets get a token" -Level Verbose
    Set-MeterToken -password $env:Bright_Meter_Password

    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no token" -Level Significant
        Break
    }
    $applicationid = 'b0f1b774-a586-4f72-9edd-27ead8aa7a8d'
    $headers = @{
        "Content-Type"  = "application/json"
        "applicationId" = "$applicationid"
        "token"         = "$env:Bright_Meter_Token"
    }
    $entity_url = 'https://api.glowmarkt.com/api/v0-1/virtualentity'
    
    try {
        Write-PSFMessage "lets get some entities" -Level Verbose
        $entities = Invoke-RestMethod -Headers $headers -Method Get -Uri $entity_url
    } catch {
        Write-PSFMessage "Error getting entities" -Level Significant
    }
    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no entities " -Level Significant
        Break
    }

    switch ($resourceType) {
        'consumption' {  
            $resourceId = ($entities.resources | Where-Object { $_.name -eq 'electricity consumption' }).resourceId
        }
        'cost' {
            $resourceId = ($entities.resources | Where-Object { $_.Name -eq 'electricity cost' }).resourceId
        }
        Default {}
    }
    

    switch ($timePeriod) {
        30Minute {
            $date = Get-Date 
            $startOfDay = $date.ToString('yyyy-MM-ddT00:00:01')
            $endOfDay = $date.ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $startOfDay # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $endOfDay 
            $period = 'PT30M'
        }
        hour {
            $date = Get-Date 
            $startOfDay = $date.ToString('yyyy-MM-ddT00:00:01')
            $endOfDay = $date.ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $startOfDay # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $endOfDay 
            $period = 'PT1H'
        }
        today {
            $date = Get-Date 
            $startOfDay = $date.ToString('yyyy-MM-ddT00:00:01')
            $endOfDay = $date.ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $startOfDay # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $endOfDay 
            $period = 'P1D'
        }
        yesterday {
            $date = Get-Date 
            $startOfDay = $date.AddDays(-1).ToString('yyyy-MM-ddT00:00:01')
            $endOfDay = $date.AddDays(-1).ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $startOfDay # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $endOfDay 
            $period = 'PT30M'
        }
        thisweek {
            $date = Get-Date  -Hour 0 -Minute 0 -Second 0
            $theFirstDayOfWeek = $date.AddDays(0 - $date.DayOfWeek.value__)
            $firstDayOfWeek = $theFirstDayOfWeek.ToString('yyyy-MM-ddT00:00:01')
            $lastDayOfWeek = $theFirstDayOfWeek.AddDays(6).ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $firstDayOfWeek # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfWeek 
            $period = 'P1D'
        }
        lastweek {
            $date = Get-Date  -Hour 0 -Minute 0 -Second 0
            $theFirstDayOfWeek = $date.AddDays(0 - $date.DayOfWeek.value__).AddDays(-7)
            $firstDayOfWeek = $theFirstDayOfWeek.ToString('yyyy-MM-ddT00:00:01')
            $lastDayOfWeek = $theFirstDayOfWeek.AddDays(6).ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $firstDayOfWeek # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfWeek 
            $period = 'P1D'
        }
        twoweeksago {
            $date = Get-Date  -Hour 0 -Minute 0 -Second 0
            $theFirstDayOfWeek = $date.AddDays(0 - $date.DayOfWeek.value__).AddDays(-14)
            $firstDayOfWeek = $theFirstDayOfWeek.ToString('yyyy-MM-ddT00:00:01')
            $lastDayOfWeek = $theFirstDayOfWeek.AddDays(6).ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $firstDayOfWeek # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfWeek 
            $period = 'P1D'
        }
        threeweeksago {
            $date = Get-Date  -Hour 0 -Minute 0 -Second 0
            $theFirstDayOfWeek = $date.AddDays(0 - $date.DayOfWeek.value__).AddDays(-21)
            $firstDayOfWeek = $theFirstDayOfWeek.ToString('yyyy-MM-ddT00:00:01')
            $lastDayOfWeek = $theFirstDayOfWeek.AddDays(6).ToString('yyyy-MM-ddT23:59:59')
            $fromDate = $firstDayOfWeek # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfWeek 
            $period = 'P1D'
        }
        month {
            $date = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
            $firstDayOfMonth = $date.ToString('yyyy-MM-01T00:00:01')
            $lastDayOfMonth = $date.AddMonths(1).AddSeconds(-1).ToString('yyyy-MM-ddTHH:mm:ss')
            $fromDate = $firstDayOfMonth # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfMonth 
            $period = 'P1D'
        }
        lastmonth {
            $date = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
            $firstDayOfMonth = $date.AddMonths(-1).ToString('yyyy-MM-01T00:00:01')
            $lastDayOfMonth = $date.AddSeconds(-1).ToString('yyyy-MM-ddTHH:mm:ss')
            $fromDate = $firstDayOfMonth # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfMonth 
            $period = 'P1D'
        }
        twomonthsago {
            $date = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
            $firstDayOfMonth = $date.addMonths(-2).ToString('yyyy-MM-01T00:00:01')
            $lastDayOfMonth = $date.AddMonths(-1).AddSeconds(-1).ToString('yyyy-MM-ddTHH:mm:ss')
            $fromDate = $firstDayOfMonth # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $lastDayOfMonth 
            $period = 'P1D'
        }
        year {
            $date = Get-Date 
            $startOfYear = $date.ToString('yyyy-01-01T00:00:01')
            $endOfYear = $date.ToString('yyyy-12-31T23:59:59')
            $fromDate = $startOfYear # start date YYYY-MM-DDTHH:MM:SS
            $toDate = $endOfYear
            $period = 'P1M'
        }
        Default {}
    }

    $Readings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $resourceId, $fromDate, $toDate, $period, $offset, $function

    try {
        Write-PSFMessage "lets get some readings" -Level Verbose
        $readings = Invoke-RestMethod -Headers $headers -Method Get -Uri $Readings_Url
    } catch {
        Write-PSFMessage "Error getting readings" -Level Significant
    }
    if ($null -eq $readings) {
        Write-PSFMessage "We have no readings" -Level Significant
        Break
    }
    switch ($resourceType) {
        consumption {
            $ColumnName = 'kwH'
        }
        cost {
            $ColumnName = 'pence'
        }
    }
    switch ($timePeriod) {
        30Minute { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Time'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('HH:mm')
                    "$ColumnName" = $_[1]
                }
            }
        }
        hour { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Time'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('HH:mm')
                    "$ColumnName" = $_[1]
                }
            }
        }
        today {  
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Time'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('HH:mm')
                    "$ColumnName" = $_[1]
                }
            }
        }
        yesterday {  
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Time'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('HH:mm')
                    "$ColumnName" = $_[1]
                }
            }
        }
        threeweeksago { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).DayOfWeek.ToString()
                    "$ColumnName" = $_[1]
                }
            }
        }
        twoweeksago { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).DayOfWeek.ToString()
                    "$ColumnName" = $_[1]
                }
            }
        }
        lastweek { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).DayOfWeek.ToString()
                    "$ColumnName" = $_[1]
                }
            }
        }
        thisweek { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).DayOfWeek.ToString()
                    "$ColumnName" = $_[1]
                }
            }
        }
        month { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('dd MMMM')
                    "$ColumnName" = $_[1]
                }
            }
        }
        lastmonth { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('dd MMMM')
                    "$ColumnName" = $_[1]
                }
            }
        }
        twomonthsago { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Date'        = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('dd MMMM')
                    "$ColumnName" = $_[1]
                }
            }
        }
        year { 
            $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Month'       = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('MMM')
                    "$ColumnName" = $_[1]
                }
            }
        }
        Default {}
    }


}

<#
.SYNOPSIS
Loads the meter data into a database

.DESCRIPTION
Loads the meter data into Loading schema in the database schema defined by the project then runs the Loading stored procedure to merge into the reporting data and updates the log table.

.PARAMETER secretName
The name of the password secret name in Secret management secret vault.

.PARAMETER userName
The user name of the user to connect to the database.

.PARAMETER sqlInstance
the name of the sql instance to connect to.

.PARAMETER database
the name of the database to connect to.

.PARAMETER secretVaultName
the name of the secret vault holding the password.

.PARAMETER DontRunRefresh
a switch to disable the refresh of the data. By default refresh is run and there is a wait for 5 minutes to attempt to wait for the refresh which is not ideal.

.EXAMPLE
Invoke-MeterDataLoad

Loads the data into the database

.NOTES
Rob Sewell July 2022
#>
function Invoke-MeterDataLoad {
    [CmdletBinding()]
    param(
        $secretName = 'homeenergy-load',
        $userName = 'Loading',
        $sqlInstance = 'beardenergysrv.database.windows.net',
        $database = 'homeelectric',
        $secretVaultName = 'beard-key-vault',
        [switch]$DontRunRefresh
    )

    Write-PSFMessage -Message "Starting Data Load" -Level Significant
    $offset = '-60'  # number of minutes offset from UTC - BST = -60
    $function = 'sum'
    if (-not $DontRunRefresh) {
        Write-PSFMessage "Lets Refresh the data" -Level Verbose

        Invoke-MeterDataRefresh

        Write-PSFMessage "Waiting for 5 minutes for the refresh" -Level Significant
        Start-Sleep -Seconds 300
    }


    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no token - lets get one" -Level Significant
        Set-MeterToken -password $env:Bright_Meter_Password
    }

    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We still have no token" -Level Significant
        Break
    }
    $applicationid = 'b0f1b774-a586-4f72-9edd-27ead8aa7a8d'
    $headers = @{
        "Content-Type"  = "application/json"
        "applicationId" = "$applicationid"
        "token"         = "$env:Bright_Meter_Token"
    }

    #region entities
    $entity_url = 'https://api.glowmarkt.com/api/v0-1/virtualentity'
    
    try {
        Write-PSFMessage "lets get some entities" -Level Verbose
        $entities = Invoke-RestMethod -Headers $headers -Method Get -Uri $entity_url
    } catch {
        Write-PSFMessage "Error getting entities" -Level Significant
    }
    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no entities " -Level Significant
        Break
    }

    $consumptionresourceId = ($entities.resources | Where-Object { $_.name -eq 'electricity consumption' }).resourceId
    $costresourceId = ($entities.resources | Where-Object { $_.Name -eq 'electricity cost' }).resourceId
    #endregion
    <#
10 Days 30 minutes PT30M
31 days 1 -Hour PT1H
31 days 1 day P1D
6 weeks 1 week P1W
1 month 366 Days P1M
1 year 366 days P1Y
#>
    #region array of time periods
    Write-PSFMessage -Message "Define all the URLs" -Level Verbose

    $array = @()
    $date = Get-Date
    $toDate = $date.ToString('yyyy-MM-ddTHH:59:59')
    # 10 days of 30 minutes PT30
    $fromDate = $date.AddDays(-10).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'PT30M'
    $10ConsumptionMinutesReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $10CostMinutesReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '30Minutes'
        URLs = @(
            @{
                'Consumption' = $10ConsumptionMinutesReadings_Url
            }
            @{
                'Cost' = $10CostMinutesReadings_Url
            }
        )
    }

    # 31 days of 1 hour PT1H
    $fromDate = $date.AddDays(-31).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'PT1H'
    $31ConsumptionHoursReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $31CostHoursReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Hour'
        Urls = @(
            @{
                'Consumption' = $31ConsumptionHoursReadings_Url
            }
            @{
                'Cost' = $31CostHoursReadings_Url
            }
        )
    }

    # 31 days of 1 day P1D
    $fromDate = $date.AddDays(-31).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1D'
    $31ConsumptionDaysReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $31CostDaysReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Day'
        Urls = @(
            @{
                'Consumption' = $31ConsumptionDaysReadings_Url
            }
            @{
                'Cost' = $31CostDaysReadings_Url
            }
        )
    }

    # 6 weeks of 1 week P1W
    $fromDate = $date.AddDays(-42).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1W'
    $6ConsumptionWeeksReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $6CostWeeksReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Week'
        Urls = @(
            @{
                'Consumption' = $6ConsumptionWeeksReadings_Url
            }
            @{
                'Cost' = $6CostWeeksReadings_Url
            }
        )
    }

    # 1 month of 366 days P1M
    $fromDate = $date.AddDays(-365).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1M'
    $1ConsumptionMonthsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $1CostMonthsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function

    $array += [PSCustomObject]@{
        Name = '1Month'
        Urls = @(
            @{
                'Consumption' = $1ConsumptionMonthsReadings_Url
            }
            @{
                'Cost' = $1CostMonthsReadings_Url
            }
        )
    }
    # 1 year of 366 days P1Y
    $fromDate = $date.AddDays(-365).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1Y'
    $1ConsumptionYearsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $1CostYearsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Year'
        URLs = @(
            @{
                Consumption = $1ConsumptionYearsReadings_Url
            }
            @{
                Cost = $1CostYearsReadings_Url
            }
        )
    }
    #endregion
    #region data load
    Write-PSFMessage -Message "Get Some secrets" -Level Verbose
    
    $secStringPassword = ConvertTo-SecureString -String $Env:Home_Energy_Database_Password -AsPlainText -Force
    [pscredential]$azureCredential = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
    Write-PSFMessage -Message "Connect to SQL Instance and build object" -Level Verbose
    while (-not $server) {
        try {
            $server = Connect-DbaInstance -SqlInstance $sqlInstance  -Database  $database -SqlCredential $azureCredential -ErrorAction Stop
            Write-PSFMessage -Message "Waiting on SQL Instance" -Level Significant
            Start-Sleep -Seconds 15
        } catch {
            Write-PSFMessage -Message "Error connecting to SQL instance" -ErrorRecord $_ -Level Significant
        }
    }

    foreach ($type in $array) {
        $message = "Get the data for {0}" -f $type.Name
        Write-PSFMessage -Message $message -Level Verbose

        foreach ($url in $type.Urls) {  
            
            $TableName = '{0}_{1}_Load' -f $type.Name, $($Url.Keys)

            $message = "Get the data from the API using {0}" -f $Url.Values
            Write-PSFMessage -Message $message -Level Verbose

            $readings = Invoke-RestMethod -Headers $headers -Method Get -Uri $($Url.Values)

            $columnName = $readings.units

            $message = "Transform the data for {0}" -f $columnName
            Write-PSFMessage -Message $message -Level Verbose

            $data = $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Time'        = $_[0]
                    'HumanTime'   = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('yyyy-MM-dd HH:mm:ss')
                    "$ColumnName" = $_[1]
                    'UpdateTime'  = $date.ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
            
            $data | Write-DbaDataTable -SqlInstance $server -Table $TableName -Schema Load -AutoCreateTable -Truncate
            $message = "Exported {0} {1} data to {2}  $TableName" -f $type.Name, $($Url.Keys), $TableName
            Write-PSFMessage $Message -Level Significant
        }
    }

    $message = 'Run the Load SP'
    Write-PSFMessage $Message -Level Significant

    Invoke-DbaQuery -SqlInstance $server -Database $database -Query "EXEC [Load].[Load]" -MessagesToOutput

}

function Get-MeterAllDataToFile {
    [CmdletBinding()]
    param(
        $path = './export/'
    )

    if (-not (Test-Path $path -ErrorAction SilentlyContinue)) {
        New-Item -ItemType Directory -Force -Path $path
    }
    $offset = '-60'  # number of minutes offset from UTC - BST = -60
    $function = 'sum'
    Write-PSFMessage "lets get a token" -Level Verbose
    Set-MeterToken -password $env:Bright_Meter_Password

    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no token" -Level Significant
        Break
    }
    $applicationid = 'b0f1b774-a586-4f72-9edd-27ead8aa7a8d'
    $headers = @{
        "Content-Type"  = "application/json"
        "applicationId" = "$applicationid"
        "token"         = "$env:Bright_Meter_Token"
    }
    $entity_url = 'https://api.glowmarkt.com/api/v0-1/virtualentity'
    
    try {
        Write-PSFMessage "lets get some entities" -Level Verbose
        $entities = Invoke-RestMethod -Headers $headers -Method Get -Uri $entity_url
    } catch {
        Write-PSFMessage "Error getting entities" -Level Significant
    }
    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no entities " -Level Significant
        Break
    }

    $consumptionresourceId = ($entities.resources | Where-Object { $_.name -eq 'electricity consumption' }).resourceId
    $costresourceId = ($entities.resources | Where-Object { $_.Name -eq 'electricity cost' }).resourceId

    <#
10 Days 30 minutes PT30M
31 days 1 -Hour PT1H
31 days 1 day P1D
6 weeks 1 week P1W
1 month 366 Days P1M
1 year 366 days P1Y
#>
    $array = @()
    $date = Get-Date
    $toDate = $date.ToString('yyyy-MM-ddTHH:59:59')
    # 10 days of 30 minutes PT30
    $fromDate = $date.AddDays(-10).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'PT30M'
    $10ConsumptionMinutesReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $10CostMinutesReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '30Minutes'
        URLs = @(
            @{
                'Consumption' = $10ConsumptionMinutesReadings_Url
            }
            @{
                'Cost' = $10CostMinutesReadings_Url
            }
        )
    }

    # 31 days of 1 hour PT1H
    $fromDate = $date.AddDays(-31).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'PT1H'
    $31ConsumptionHoursReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $31CostHoursReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Hour'
        Urls = @(
            @{
                'Consumption' = $31ConsumptionHoursReadings_Url
            }
            @{
                'Cost' = $31CostHoursReadings_Url
            }
        )
    }

    # 31 days of 1 day P1D
    $fromDate = $date.AddDays(-31).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1D'
    $31ConsumptionDaysReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $31CostDaysReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Day'
        Urls = @(
            @{
                'Consumption' = $31ConsumptionDaysReadings_Url
            }
            @{
                'Cost' = $31CostDaysReadings_Url
            }
        )
    }

    # 6 weeks of 1 week P1W
    $fromDate = $date.AddDays(-42).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1W'
    $6ConsumptionWeeksReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $6CostWeeksReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Week'
        Urls = @(
            @{
                'Consumption' = $6ConsumptionWeeksReadings_Url
            }
            @{
                'Cost' = $6CostWeeksReadings_Url
            }
        )
    }

    # 1 month of 366 days P1M
    $fromDate = $date.AddDays(-365).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1M'
    $1ConsumptionMonthsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $1CostMonthsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function

    $array += [PSCustomObject]@{
        Name = '1Month'
        Urls = @(
            @{
                'Consumption' = $1ConsumptionMonthsReadings_Url
            }
            @{
                'Cost' = $1CostMonthsReadings_Url
            }
        )
    }
    # 1 year of 366 days P1Y
    $fromDate = $date.AddDays(-365).ToString('yyyy-MM-ddTHH:00:01')
    $period = 'P1Y'
    $1ConsumptionYearsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $consumptionresourceId, $fromDate, $toDate, $period, $offset, $function
    $1CostYearsReadings_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/readings?from={1}&to={2}&period={3}&offset={4}&function={5}' -f $costresourceId, $fromDate, $toDate, $period, $offset, $function
    $array += [PSCustomObject]@{
        Name = '1Year'
        URLs = @(
            @{
                Consumption = $1ConsumptionYearsReadings_Url
            }
            @{
                Cost = $1CostYearsReadings_Url
            }
        )
    }
    #endregion

    foreach ($type in $array) {

        foreach ($url in $type.Urls) {  
            
            $FileName = '{0}/{1}_{2}_{3}.csv' -f $path, $type.Name, $($Url.Keys), $date.ToString('yyyy-MM-dd-HH-mm-ss')
            $readings = Invoke-RestMethod -Headers $headers -Method Get -Uri $($Url.Values)

            $columnName = $readings.units

            $data = $readings.data | ForEach-Object {
                [PSCustomObject]@{
                    'Time'        = $_[0]
                    'HumanTime'   = ([datetime]'1/1/1970').AddSeconds($_[0]).ToString('yyyy-MM-dd HH:mm:ss') 
                    "$ColumnName" = $_[1]
                    'UpdateTime'  = $date.ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
            
            $data | Export-Csv -Path $FileName 
            $message = "Exported {0} {1} data to {2}" -f $type.Name, $($Url.Keys), $FileName
            Write-PSFMessage $Message -Level Significant
        }
    }
}

<#
.SYNOPSIS
Returns the comparison for consumption or cost by day name for the last 4 weeks including this week or the daily consumption for the last 3 months including this month

.DESCRIPTION
Returns the comparison for consumption or cost by day name for the last 4 weeks including this week or the daily consumption for the last 3 months including this month.

.PARAMETER type
week or month

.PARAMETER resourceType
cost or consumption

.EXAMPLE
Get-MeterDataComparison -type week -resourceType consumption 

Day           : Sunday
LastWeek      : 15.567
ThisWeek      : 44.002
TwoWeeksAgo   : 20.818
ThreeWeeksAgo : 17.992

Day           : Monday
LastWeek      : 22.615
ThisWeek      : 48.053
TwoWeeksAgo   : 24.032
ThreeWeeksAgo : 20.45

Day           : Tuesday
LastWeek      : 18.045
ThisWeek      : 19.717
TwoWeeksAgo   : 20.42
ThreeWeeksAgo : 19.405

Day           : Wednesday
LastWeek      : 16.792
ThisWeek      : 17.561
TwoWeeksAgo   : 19.646
ThreeWeeksAgo : 18.549

Day           : Thursday
LastWeek      : 17.317
ThisWeek      : 19.873
TwoWeeksAgo   : 18.146
ThreeWeeksAgo : 20.164

Day           : Friday
LastWeek      : 18.035
ThisWeek      : 14.528
TwoWeeksAgo   : 19.731
ThreeWeeksAgo : 19.317

Day           : Saturday
LastWeek      : 16.291
ThisWeek      : 0
TwoWeeksAgo   : 17.033
ThreeWeeksAgo : 17.95

Compares the last 4 weeks consumption by day name

.NOTES
Rob Sewell July 2022
#>
function Get-MeterDataComparison {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('week', 'month')]
        [string]$type,
        [ValidateSet('consumption', 'cost')]
        $resourceType = 'consumption'
    )
    switch ($type) {
        week { 
            $lastweek = Get-MeterData -ResourceType $resourceType -TimePeriod 'lastweek'
            $thisweek = Get-MeterData -ResourceType $resourceType -TimePeriod 'thisweek'
            $twoweeksago = Get-MeterData -ResourceType $resourceType -TimePeriod 'twoweeksago'
            $threeweeksago = Get-MeterData -ResourceType $resourceType -TimePeriod 'threeweeksago'  
            foreach ($day in $lastweek) {
                switch ($resourceType) {
                    consumption {
                        $ColumnName = 'kwH'
                        [PSCustomObject]@{
                            Day           = $day.Date
                            LastWeek      = $day.$ColumnName
                            ThisWeek      = $thisweek.Where({ $_.Date -eq $day.Date }).$ColumnName
                            TwoWeeksAgo   = $twoweeksago.Where({ $_.Date -eq $day.Date }).$ColumnName
                            ThreeWeeksAgo = $threeweeksago.Where({ $_.Date -eq $day.Date }).$ColumnName
                        }
                    }
                    cost {
                        $ColumnName = 'pence'
                        [PSCustomObject]@{
                            Day           = $day.Date
                            LastWeek      = $day.$ColumnName
                            ThisWeek      = $thisweek.Where({ $_.Date -eq $day.Date }).$ColumnName
                            TwoWeeksAgo   = $twoweeksago.Where({ $_.Date -eq $day.Date }).$ColumnName
                            ThreeWeeksAgo = $threeweeksago.Where({ $_.Date -eq $day.Date }).$ColumnName
                        }

                    }
                }
            }
        }
        month {
            $monthToDate = Get-MeterData -ResourceType $resourceType  -TimePeriod 'month'
            $lastmonth = Get-MeterData -ResourceType $resourceType  -TimePeriod 'lastmonth'
            $twomonthsago = Get-MeterData -ResourceType $resourceType  -TimePeriod 'twomonthsago'
            foreach ($number in 1..31) {

                switch ($resourceType) {
                    consumption {
                        $ColumnName = 'kwH'
                        [PSCustomObject]@{
                            Day          = $number
                            ThisMonth    = $monthToDate.Where({ $_.Date.Split(' ')[0] -eq ('{0:d2}' -f $number) }).$ColumnName
                            LastMonth    = $lastmonth.Where({ $_.Date.Split(' ')[0] -eq ('{0:d2}' -f $number) }).$ColumnName
                            TwoMonthsAgo = $twomonthsago.Where({ $_.Date.Split(' ')[0] -eq ('{0:d2}' -f $number) }).$ColumnName
                        }
                    }
                    cost {
                        $ColumnName = 'pence'
                        [PSCustomObject]@{
                            Day          = $number
                            ThisMonth    = $monthToDate.Where({ $_.Date.Split(' ')[0] -eq ('{0:d2}' -f $number) }).$ColumnName / 100
                            LastMonth    = $lastmonth.Where({ $_.Date.Split(' ')[0] -eq ('{0:d2}' -f $number) }).$ColumnName / 100
                            TwoMonthsAgo = $twomonthsago.Where({ $_.Date.Split(' ')[0] -eq ('{0:d2}' -f $number) }).$ColumnName / 100
                        }
                    }
                }
            }
        }
        Default {}
    }
}

<#
.SYNOPSIS
What this should do is set off a refresh of the data in the Bright Api from the meter. Sometimes it works in about 5 minutes, sometimes it seems to do naff all. To be fair the button in the app does exactly the same so I think it is supplier related

.DESCRIPTION
What this should do is set off a refresh of the data in the Bright Api from the meter. Sometimes it works in about 5 minutes, sometimes it seems to do naff all. To be fair the button in the app does exactly the same so I think it is supplier related

.EXAMPLE
Invoke-MeterDataRefresh

Asks the Bright API to refresh the data from the meter. This may or not be successful

.NOTES
Rob Sewell July 2022
#>
function Invoke-MeterDataRefresh {

    Write-PSFMessage "lets get a token" -Level Verbose
    Set-MeterToken -password $env:Bright_Meter_Password

    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no token" -Level Significant
        Break
    }
    $applicationid = 'b0f1b774-a586-4f72-9edd-27ead8aa7a8d'
    $headers = @{
        "Content-Type"  = "application/json"
        "applicationId" = "$applicationid"
        "token"         = "$env:Bright_Meter_Token"
    }
    $entity_url = 'https://api.glowmarkt.com/api/v0-1/virtualentity'
    
    try {
        Write-PSFMessage "lets get some entities" -Level Verbose
        $entities = Invoke-RestMethod -Headers $headers -Method Get -Uri $entity_url
    } catch {
        Write-PSFMessage "Error getting entities" -Level Significant
    }
    if ($null -eq $env:Bright_Meter_Token) {
        Write-PSFMessage "We have no entities " -Level Significant
        Break
    }

    $consumptionResourceID = ($entities.resources | Where-Object { $_.name -eq 'electricity consumption' }).resourceId

    $costResourceID = ($entities.resources | Where-Object { $_.Name -eq 'electricity cost' }).resourceId
    
    $Consumption_Update_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/catchup' -f $consumptionResourceID
    $Cost_Update_Url = 'https://api.glowmarkt.com/api/v0-1/resource/{0}/catchup' -f $costResourceID

    Invoke-RestMethod -Headers $headers -Method Get -Uri $Consumption_Update_Url
    Invoke-RestMethod -Headers $headers -Method Get -Uri $Cost_Update_Url

}

