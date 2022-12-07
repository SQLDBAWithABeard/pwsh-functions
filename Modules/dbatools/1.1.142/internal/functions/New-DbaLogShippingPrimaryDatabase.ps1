function New-DbaLogShippingPrimaryDatabase {
    <#
        .SYNOPSIS
            New-DbaLogShippingPrimaryDatabase add the primary database to log shipping

        .DESCRIPTION
            New-DbaLogShippingPrimaryDatabase will add the primary database to log shipping.
            This is executed on the primary server.

        .PARAMETER SqlInstance
            SQL Server instance. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Database
            Database to set up log shipping for.

        .PARAMETER BackupDirectory
            Is the path to the backup folder on the primary server.

        .PARAMETER BackupJob
            Is the name of the SQL Server Agent job on the primary server that copies the backup into the backup folder.

        .PARAMETER BackupJobID
            The SQL Server Agent job ID associated with the backup job on the primary server.

        .PARAMETER BackupRetention
            Is the length of time, in minutes, to retain the log backup file in the backup directory on the primary server.

        .PARAMETER BackupShare
            Is the network path to the backup directory on the primary server.

        .PARAMETER BackupThreshold
            Is the length of time, in minutes, after the last backup before a threshold_alert error is raised.
            The default is 60.

        .PARAMETER CompressBackup
            Enables the use of backup compression

        .PARAMETER ThresholdAlert
            Is the length of time, in minutes, when the alert is to be raised when the backup threshold is exceeded.
            The default is 14,420.

        .PARAMETER HistoryRetention
            Is the length of time in minutes in which the history will be retained.
            The default is 14420.

        .PARAMETER MonitorServer
            Is the name of the monitor server.
            The default is the name of the primary server.

        .PARAMETER MonitorCredential
            Allows you to login to enter a secure credential.
            This is only needed in combination with MonitorServerSecurityMode having either a 0 or 'sqlserver' value.
            To use: $scred = Get-Credential, then pass $scred object to the -MonitorCredential parameter.

        .PARAMETER MonitorServerSecurityMode
            The security mode used to connect to the monitor server. Allowed values are 0, "sqlserver", 1, "windows"
            The default is 1 or Windows.

        .PARAMETER ThresholdAlertEnabled
            Specifies whether an alert will be raised when backup threshold is exceeded.
            The default is 0.

        .PARAMETER WhatIf
            Shows what would happen if the command were to run. No actions are actually performed.

        .PARAMETER Confirm
            Prompts you for confirmation before executing any changing operations within the command.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .PARAMETER Force
            The force parameter will ignore some errors in the parameters and assume defaults.
            It will also remove the any present schedules with the same name for the specific job.

        .NOTES
            Author: Sander Stad (@sqlstad, sqlstad.nl)
            Website: https://dbatools.io
            Copyright: (c) 2018 by dbatools, licensed under MIT
            License: MIT https://opensource.org/licenses/MIT

        .EXAMPLE
            New-DbaLogShippingPrimaryDatabase -SqlInstance sql1 -Database DB1 -BackupDirectory D:\data\logshipping -BackupJob LSBackup_DB1 -BackupRetention 4320 -BackupShare "\\sql1\logshipping" -BackupThreshold 60 -CompressBackup -HistoryRetention 14420 -MonitorServer sql1 -ThresholdAlertEnabled

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]

    param (
        [parameter(Mandatory)]
        [object]$SqlInstance,
        [System.Management.Automation.PSCredential]$SqlCredential,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$Database,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BackupDirectory,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BackupJob,
        [Parameter(Mandatory)]
        [int]$BackupRetention,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BackupShare,
        [int]$BackupThreshold = 60,
        [switch]$CompressBackup,
        [int]$ThresholdAlert = 14420,
        [int]$HistoryRetention = 14420,
        [string]$MonitorServer,
        [ValidateSet(0, "sqlserver", 1, "windows")]
        [object]$MonitorServerSecurityMode = 1,
        [System.Management.Automation.PSCredential]$MonitorCredential,
        [switch]$ThresholdAlertEnabled,
        [switch]$EnableException,
        [switch]$Force
    )

    # Try connecting to the instance
    try {
        $server = Connect-DbaInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
    } catch {
        Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $SqlInstance
        return
    }

    # Check if the backup UNC path is correct and reachable
    if ([bool]([uri]$BackupShare).IsUnc -and $BackupShare -notmatch '^\\(?:\\[^<>:`"/\\|?*]+)+$') {
        Stop-Function -Message "The backup share path $BackupShare should be formatted in the form \\server\share." -Target $SqlInstance
        return
    } else {
        if (-not ((Test-Path $BackupShare -PathType Container -IsValid) -and ((Get-Item $BackupShare).PSProvider.Name -eq 'FileSystem'))) {
            Stop-Function -Message "The backup share path $BackupShare is not valid or can't be reached." -Target $SqlInstance
            return
        }
    }

    # Check the backup compression
    if ($CompressBackup -eq $true) {
        Write-Message -Message "Setting backup compression to 1." -Level Verbose
        $BackupCompression = 1
    } elseif ($CompressBackup -eq $false) {
        Write-Message -Message "Setting backup compression to 0." -Level Verbose
        $BackupCompression = 0
    } elseif (-not $CompressBackup) {
        $defaultCompression = (Get-DbaSpConfigure -SqlInstance $server -ConfigName DefaultBackupCompression).ConfiguredValue
        Write-Message -Message "Setting backup compression to default value $defaultCompression." -Level Verbose
        $BackupCompression = $defaultCompression

    }

    # Check of the MonitorServerSecurityMode value is of type string and set the integer value
    if ($MonitorServerSecurityMode -notin 0, 1) {
        $MonitorServerSecurityMode = switch ($MonitorServerSecurityMode) { "WINDOWS" { 1 } "SQLSERVER" { 0 } }
        Write-Message -Message "Setting monitor server security mode to $MonitorServerSecurityMode." -Level Verbose
    }

    # Check the MonitorServer
    if (-not $MonitorServer -and $Force) {
        Write-Message -Message "Setting monitor server to $SqlInstance." -Level Verbose
        $MonitorServer = $SqlInstance
    }

    # Check the MonitorServerSecurityMode if it's SQL Server authentication
    if ($MonitorServerSecurityMode -eq 0 -and -not $MonitorCredential) {
        Stop-Function -Message "The MonitorServerCredential cannot be empty when using SQL Server authentication." -Target $SqlInstance
        return
    } elseif ($MonitorServerSecurityMode -eq 0 -and $MonitorCredential) {
        # Get the username and password from the credential
        $MonitorLogin = $MonitorCredential.UserName
        $MonitorPassword = $MonitorCredential.GetNetworkCredential().Password

        # Check if the user is in the database
        if ($server.Databases['master'].Users.Name -notcontains $MonitorLogin) {
            Stop-Function -Message "User $MonitorLogin for monitor login must be in the master database." -Target $SqlInstance
            return
        }
    }

    # Check if the database is present on the source sql server
    if ($server.Databases.Name -notcontains $Database) {
        Stop-Function -Message "Database $Database is not available on instance $SqlInstance" -Target $SqlInstance
        return
    }

    # Check the if Threshold alert needs to be enabled
    if ($ThresholdAlertEnabled) {
        [int]$ThresholdAlertEnabled = 1
        Write-Message -Message "Setting Threshold alert to $ThresholdAlertEnabled." -Level Verbose
    } else {
        [int]$ThresholdAlertEnabled = 0
        Write-Message -Message "Setting Threshold alert to $ThresholdAlertEnabled." -Level Verbose
    }

    # Set the log shipping primary
    $Query = "
        DECLARE @LS_BackupJobId AS uniqueidentifier;
        DECLARE @LS_PrimaryId AS uniqueidentifier;
        EXEC master.sys.sp_add_log_shipping_primary_database
            @database = N'$Database'
            ,@backup_directory = N'$BackupDirectory'
            ,@backup_share = N'$BackupShare'
            ,@backup_job_name = N'$BackupJob'
            ,@backup_retention_period = $BackupRetention
            ,@backup_threshold = $BackupThreshold
            ,@history_retention_period = $HistoryRetention
            ,@backup_job_id = @LS_BackupJobId OUTPUT
            ,@primary_id = @LS_PrimaryId OUTPUT "

    if ($server.Version.Major -gt 9) {
        $Query += ",@backup_compression = $BackupCompression"
    }

    if ($MonitorServer) {
        $Query += "
            ,@monitor_server = N'$MonitorServer'
            ,@monitor_server_security_mode = $MonitorServerSecurityMode
            ,@threshold_alert = $ThresholdAlert
            ,@threshold_alert_enabled = $ThresholdAlertEnabled"

        #if ($MonitorServer -and ($SqlInstance.Version.Major -ge 16)) {
        if ($server.Version.Major -ge 12) {
            # Check the MonitorServerSecurityMode if it's SQL Server authentication
            if ($MonitorServer -and $MonitorServerSecurityMode -eq 0 ) {
                $Query += "
                    ,@monitor_server_login = N'$MonitorLogin'
                    ,@monitor_server_password = N'$MonitorPassword' "
            }
        } else {
            $Query += "
                ,@ignoreremotemonitor = 1"
        }
    }

    if ($Force -or ($server.Version.Major -gt 9)) {
        $Query += "
            ,@overwrite = 1;"
    } else {
        $Query += ";"
    }

    # Execute the query to add the log shipping primary
    if ($PSCmdlet.ShouldProcess($SqlServer, ("Configuring logshipping for primary database $Database on $SqlInstance"))) {
        try {
            Write-Message -Message "Configuring logshipping for primary database $Database." -Level Verbose
            Write-Message -Message "Executing query:`n$Query" -Level Verbose
            $server.Query($Query)

            # For versions prior to SQL Server 2014, adding a monitor works in a different way.
            # The next section makes sure the settings are being synchronized with earlier versions
            if ($MonitorServer -and ($server.Version.Major -lt 12)) {
                # Get the details of the primary database
                $query = "SELECT * FROM msdb.dbo.log_shipping_monitor_primary WHERE primary_database = '$Database'"
                $lsDetails = $server.Query($query)

                # Setup the procedure script for adding the monitor for the primary
                $query = "EXEC msdb.dbo.sp_processlogshippingmonitorprimary @mode = $MonitorServerSecurityMode
                    ,@primary_id = '$($lsDetails.primary_id)'
                    ,@primary_server = '$($lsDetails.primary_server)'
                    ,@monitor_server = '$MonitorServer' "

                # Check the MonitorServerSecurityMode if it's SQL Server authentication
                if ($MonitorServer -and $MonitorServerSecurityMode -eq 0 ) {
                    $query += "
                    ,@monitor_server_login = N'$MonitorLogin'
                    ,@monitor_server_password = N'$MonitorPassword' "
                }

                $query += "
                    ,@monitor_server_security_mode = 1
                    ,@primary_database = '$($lsDetails.primary_database)'
                    ,@backup_threshold = $($lsDetails.backup_threshold)
                    ,@threshold_alert = $($lsDetails.threshold_alert)
                    ,@threshold_alert_enabled = $([int]$lsDetails.threshold_alert_enabled)
                    ,@history_retention_period = $($lsDetails.history_retention_period)
                "

                Write-Message -Message "Configuring monitor server for primary database $Database." -Level Verbose
                Write-Message -Message "Executing query:`n$query" -Level Verbose
                Invoke-DbaQuery -SqlInstance $MonitorServer -SqlCredential $MonitorCredential -Database msdb -Query $query

                $query = "
                    UPDATE msdb.dbo.log_shipping_primary_databases
                    SET monitor_server = '$MonitorServer', user_specified_monitor = 1
                    WHERE primary_id = '$($lsDetails.primary_id)'
                "
                Write-Message -Message "Updating monitor information for the primary database $Database." -Level Verbose
                Write-Message -Message "Executing query:`n$query" -Level Verbose
                $server.Query($query)
            }
        } catch {
            Write-Message -Message "$($_.Exception.InnerException.InnerException.InnerException.InnerException.Message)" -Level Warning
            Stop-Function -Message "Error executing the query.`n$($_.Exception.Message)`n$($Query)" -ErrorRecord $_ -Target $SqlInstance -Continue
        }
    }

    Write-Message -Message "Finished adding the primary database $Database to log shipping." -Level Verbose

}
# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCfGn42ZQ5vZq2G
# 5c3C5EikpneG1Jq5gIgxjujOoGoArqCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
# Y1+/3q4SBOdtMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcN
# MjAwNTEyMDAwMDAwWhcNMjMwNjA4MTIwMDAwWjBXMQswCQYDVQQGEwJVUzERMA8G
# A1UECBMIVmlyZ2luaWExDzANBgNVBAcTBlZpZW5uYTERMA8GA1UEChMIZGJhdG9v
# bHMxETAPBgNVBAMTCGRiYXRvb2xzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAvL9je6vjv74IAbaY5rXqHxaNeNJO9yV0ObDg+kC844Io2vrHKGD8U5hU
# iJp6rY32RVprnAFrA4jFVa6P+sho7F5iSVAO6A+QZTHQCn7oquOefGATo43NAadz
# W2OWRro3QprMPZah0QFYpej9WaQL9w/08lVaugIw7CWPsa0S/YjHPGKQ+bYgI/kr
# EUrk+asD7lvNwckR6pGieWAyf0fNmSoevQBTV6Cd8QiUfj+/qWvLW3UoEX9ucOGX
# 2D8vSJxL7JyEVWTHg447hr6q9PzGq+91CO/c9DWFvNMjf+1c5a71fEZ54h1mNom/
# XoWZYoKeWhKnVdv1xVT1eEimibPEfQIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAU
# WsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYEFPDAoPu2A4BDTvsJ193ferHL
# 454iMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8E
# cDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVk
# LWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTIt
# YXNzdXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggr
# BgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEw
# gYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/
# BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAj835cJUMH9Y2pBKspjznNJwcYmOxeBcH
# Ji+yK0y4bm+j44OGWH4gu/QJM+WjZajvkydJKoJZH5zrHI3ykM8w8HGbYS1WZfN4
# oMwi51jKPGZPw9neGS2PXrBcKjzb7rlQ6x74Iex+gyf8z1ZuRDitLJY09FEOh0BM
# LaLh+UvJ66ghmfIyjP/g3iZZvqwgBhn+01fObqrAJ+SagxJ/21xNQJchtUOWIlxR
# kuUn9KkuDYrMO70a2ekHODcAbcuHAGI8wzw4saK1iPPhVTlFijHS+7VfIt/d/18p
# MLHHArLQQqe1Z0mTfuL4M4xCUKpebkH8rI3Fva62/6osaXLD0ymERzCCBTAwggQY
# oAMCAQICEAQJGBtf1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4X
# DTEzMTAyMjEyMDAwMFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEx
# MC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBD
# QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsx
# SRnP0PtFmbE620T1f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawO
# eSg6funRZ9PG+yknx9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJ
# RdQtoaPpiCwgla4cSocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEc
# z+ryCuRXu0q16XTmK/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whk
# PlKWwfIPEvTFjg/BougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8l
# k9ECAwEAAaOCAc0wggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQD
# AgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARI
# MEYwOAYKYIZIAYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdp
# Y2VydC5jb20vQ1BTMAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg
# +S32ZXUOWDAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG
# 9w0BAQsFAAOCAQEAPuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/E
# r4v97yrfIFU3sOH20ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3
# nEZOXP+QsRsHDpEV+7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpo
# aK+bp1wgXNlxsQyPu6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW
# 6Fkd6fp0ZGuy62ZD2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ
# 92JuoVP6EpQYhS6SkepobEQysmah5xikmmRR7zCCBY0wggR1oAMCAQICEA6bGI75
# 0C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAw
# MFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGln
# aUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuE
# DcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNw
# wrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs0
# 6wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e
# 5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtV
# gkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85
# tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+S
# kjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1Yxw
# LEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzl
# DlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFr
# b7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATow
# ggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiu
# HA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQE
# AwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2
# hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290
# Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/
# Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNK
# ei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHr
# lnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4
# oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5A
# Y8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNN
# n3O3AamfV6peKOK5lDCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVow
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklR
# VcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54P
# Mx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupR
# PfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvo
# hGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV
# 5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYV
# VSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6i
# c/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/Ci
# PMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5
# K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oi
# qMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuld
# yF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvH
# UF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0M
# CIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCK
# rOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rA
# J4JErpknG6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZ
# xhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScs
# PT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1M
# rfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXse
# GYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWY
# MbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYp
# hwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPww
# ggbAMIIEqKADAgECAhAMTWlyS5T6PCpKPSkHgD1aMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjIwOTIxMDAwMDAwWhcNMzMxMTIxMjM1OTU5WjBGMQswCQYDVQQGEwJV
# UzERMA8GA1UEChMIRGlnaUNlcnQxJDAiBgNVBAMTG0RpZ2lDZXJ0IFRpbWVzdGFt
# cCAyMDIyIC0gMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAM/spSY6
# xqnya7uNwQ2a26HoFIV0MxomrNAcVR4eNm28klUMYfSdCXc9FZYIL2tkpP0GgxbX
# kZI4HDEClvtysZc6Va8z7GGK6aYo25BjXL2JU+A6LYyHQq4mpOS7eHi5ehbhVsbA
# umRTuyoW51BIu4hpDIjG8b7gL307scpTjUCDHufLckkoHkyAHoVW54Xt8mG8qjoH
# ffarbuVm3eJc9S/tjdRNlYRo44DLannR0hCRRinrPibytIzNTLlmyLuqUDgN5YyU
# XRlav/V7QG5vFqianJVHhoV5PgxeZowaCiS+nKrSnLb3T254xCg/oxwPUAY3ugjZ
# Naa1Htp4WB056PhMkRCWfk3h3cKtpX74LRsf7CtGGKMZ9jn39cFPcS6JAxGiS7uY
# v/pP5Hs27wZE5FX/NurlfDHn88JSxOYWe1p+pSVz28BqmSEtY+VZ9U0vkB8nt9Kr
# FOU4ZodRCGv7U0M50GT6Vs/g9ArmFG1keLuY/ZTDcyHzL8IuINeBrNPxB9Thvdld
# S24xlCmL5kGkZZTAWOXlLimQprdhZPrZIGwYUWC6poEPCSVT8b876asHDmoHOWIZ
# ydaFfxPZjXnPYsXs4Xu5zGcTB5rBeO3GiMiwbjJ5xwtZg43G7vUsfHuOy2SJ8bHE
# uOdTXl9V0n0ZKVkDTvpd6kVzHIR+187i1Dp3AgMBAAGjggGLMIIBhzAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAg
# BgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZ
# bU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFGKK3tBh/I8xFO2XC809KpQU31Kc
# MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAG
# CCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2Vy
# dC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQw
# DQYJKoZIhvcNAQELBQADggIBAFWqKhrzRvN4Vzcw/HXjT9aFI/H8+ZU5myXm93KK
# mMN31GT8Ffs2wklRLHiIY1UJRjkA/GnUypsp+6M/wMkAmxMdsJiJ3HjyzXyFzVOd
# r2LiYWajFCpFh0qYQitQ/Bu1nggwCfrkLdcJiXn5CeaIzn0buGqim8FTYAnoo7id
# 160fHLjsmEHw9g6A++T/350Qp+sAul9Kjxo6UrTqvwlJFTU2WZoPVNKyG39+Xgmt
# dlSKdG3K0gVnK3br/5iyJpU4GYhEFOUKWaJr5yI+RCHSPxzAm+18SLLYkgyRTzxm
# lK9dAlPrnuKe5NMfhgFknADC6Vp0dQ094XmIvxwBl8kZI4DXNlpflhaxYwzGRkA7
# zl011Fk+Q5oYrsPJy8P7mxNfarXH4PMFw1nfJ2Ir3kHJU7n/NBBn9iYymHv+XEKU
# gZSCnawKi8ZLFUrTmJBFYDOA4CPe+AOk9kVH5c64A0JH6EE2cXet/aLol3ROLtoe
# HYxayB6a1cLwxiKoT5u92ByaUcQvmvZfpyeXupYuhVfAYOd4Vn9q78KVmksRAsiC
# nMkaBXy6cbVOepls9Oie1FqYyJ+/jbsYXEP10Cro4mLueATbvdH7WwqocH7wl4R4
# 4wgDXUcsY6glOJcB0j862uXl9uab3H4szP8XTE0AotjWAQ64i+7m4HJViSwnGWH2
# dwGMMYIFXTCCBVkCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQAwW7hiGwoWNf
# v96uEgTnbTANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAM
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCa1ACRsfTL1ev0dXUjxbWt4G1U
# l/vfqxG8ciFal6MuNzANBgkqhkiG9w0BAQEFAASCAQAkt3z6hLhbRI4bctUp+pWx
# rOzXbgkqA8TJPo2B0PdBWtXkvUTkiZhAljdvhQzsfqZzenxKHvhXH7Z1ZwmiHvIN
# YgNX9I7AyqpH+fOP89HLxieDQcR+MgH00RCHBCpzFn+jkTNbbpmVIaLiQXkbs7mZ
# ic9ki/kZvWLh8Ye5wkyfSZW4hg5pD+oxPirws6srsouUSo6hZkykhKSBLywj5WWA
# fM8Kbz8ZwD8heGDxzLZiMhV5Q1ga4Z7hnNYeraKZoYN7mIhnKSmjvvr3R9tyKFLV
# wm9vxsbGIBqkQm75M3owlAqyGPgGEgSdZaHp8qLnL5DAu999EOrdiRi0Pm6p7GwI
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIyMTAyMjIwMzgyOFowLwYJKoZIhvcNAQkEMSIE
# IGl8G55citMGQtl/4v4nZc8NC5O+vyTZ+zf3Tz+ZtccbMA0GCSqGSIb3DQEBAQUA
# BIICAItaXZ4xCgxsTqLl2W5AzPimGk6umLzr+rP3pH2UzaUeZd02D285HhViE3CU
# zYF0qkMfEr1d1pdLF8G/bsVSwUxemww1UZFv73EQ7kiBn1BObwXz7jJNbWWA2B64
# V5SRNh8ad3Ygj+/gL8nLWvRtyMfTKwQoNo0FsfOGpHvNyoDBou1Jr6UfG9Cy6gUt
# hvOxatccsZOi4rj5y+F0xyrLeRI7fHvpitjpzWyaoJPHEd8woTFLnh+2loTEOCpc
# E66QA4/vNG8JIaIFqfELlYLL6wa2iLPXxkUASNCopybut3Iv8QzbbSqD8tQZBP4a
# 3YIGz89iLkWXWcm4jncmfobP009hdPVEEpmTYTQ0KZ1ZddMub8E/Xu02xzaWK3Fb
# jplAS+4M0V/W6dNsEAfo5GRiXF+nweXfS3ISSmDi3afAKQmh6RGOZWyGdW+oxJbo
# V+L3oBpQVE6D6T2xdMME+uMIsNi/yTtQT075lEAN5gLCLM8q9ch85O9RFptZz8I7
# f6NUngi7roiU0I6v6rVuI07P6+wva118n3FO6O6Z2kQKkK7oTBFpT1Lf2OnNw7pQ
# vOek2/+CiGTHfL0bZO5ftFVn8pZ0UicdqP1OfjE5YdjV+V7Ujcvs79mYWpAQwKg/
# 0PAxVnriwNr96bRRrAoAAONRpZRb5oFPF0F63d0RNt2/WEYl
# SIG # End signature block
