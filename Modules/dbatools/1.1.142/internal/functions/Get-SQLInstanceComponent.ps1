function Get-SQLInstanceComponent {
    <#
    .SYNOPSIS
        Retrieves SQL server information from a local or remote servers.
    .DESCRIPTION
        Retrieves SQL server information from a local or remote servers. Pulls all instances from a SQL server and
        detects if in a cluster or not.
    .PARAMETER ComputerName
        Local or remote systems to query for SQL information.
    .NOTES
        Tags: Install, Patching, SP, CU, Instance
        Author: Kirill Kravtsov (@nvarscar), nvarscar.wordpress.com

        Based on https://github.com/adbertram/PSSqlUpdater
        The majority of this function was created by Boe Prox.
    .EXAMPLE
        Get-SQLInstanceComponent -ComputerName SQL01 -Component SSDS
        ComputerName  : BDT005-BT-SQL
        InstanceType  : Database Engine
        InstanceName  : MSSQLSERVER
        InstanceID    : MSSQL11.MSSQLSERVER
        Edition       : Enterprise Edition
        Version       : 11.1.3000.0
        Caption       : SQL Server 2012
        IsCluster     : False
        IsClusterNode : False
        ClusterName   :
        ClusterNodes  : {}
        FullName      : BDT005-BT-SQL
        Description
        -----------
        Retrieves the SQL instance information from SQL01 for component type SSDS (Database Engine).
    .EXAMPLE
        Get-SQLInstanceComponent -ComputerName SQL01
        ComputerName  : BDT005-BT-SQL
        InstanceType  : Analysis Services
        InstanceName  : MSSQLSERVER
        InstanceID    : MSAS11.MSSQLSERVER
        Edition       : Enterprise Edition
        Version       : 11.1.3000.0
        Caption       : SQL Server 2012
        IsCluster     : False
        IsClusterNode : False
        ClusterName   :
        ClusterNodes  : {}
        FullName      : BDT005-BT-SQL
        ComputerName  : BDT005-BT-SQL
        InstanceType  : Reporting Services
        InstanceName  : MSSQLSERVER
        InstanceID    : MSRS11.MSSQLSERVER
        Edition       : Enterprise Edition
        Version       : 11.1.3000.0
        Caption       : SQL Server 2012
        IsCluster     : False
        IsClusterNode : False
        ClusterName   :
        ClusterNodes  : {}
        FullName      : BDT005-BT-SQL
        Description
        -----------
        Retrieves the SQL instance information from SQL01 for all component types (SSAS, SSDS, SSRS).
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Computer', 'DNSHostName', 'IPAddress')]
        [DbaInstanceParameter[]]$ComputerName = $Env:COMPUTERNAME,
        [ValidateSet('SSDS', 'SSAS', 'SSRS')]
        [string[]]$Component = @('SSDS', 'SSAS', 'SSRS'),
        [pscredential]$Credential
    )

    begin {

        $regScript = {
            Param (
                $ComponentObject
            )
            $Component = $ComponentObject.Component
            $componentNameMap = @(
                [pscustomobject]@{
                    ComponentName = 'SSAS';
                    DisplayName   = 'Analysis Services';
                    RegKeyName    = "OLAP";
                },
                [pscustomobject]@{
                    ComponentName = 'SSDS';
                    DisplayName   = 'Database Engine';
                    RegKeyName    = 'SQL';
                },
                [pscustomobject]@{
                    ComponentName = 'SSRS';
                    DisplayName   = 'Reporting Services';
                    RegKeyName    = 'RS';
                }
            );

            function Get-SQLInstanceDetail {
                <#
                    .SYNOPSIS
                        The majority of this function was created by Boe Prox.
                #>
                param
                (
                    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
                    [string[]]$Instance,

                    [Parameter(Mandatory)]
                    [ValidateNotNullOrEmpty()]
                    [Microsoft.Win32.RegistryKey]$RegKey,

                    [Parameter(Mandatory)]
                    [ValidateNotNullOrEmpty()]
                    [Microsoft.Win32.RegistryKey]$reg,

                    [Parameter(Mandatory)]
                    [ValidateNotNullOrEmpty()]
                    [string]$RegPath
                )
                process {
                    #region Process each instance
                    foreach ($sqlInstance in $Instance) {
                        $log = @()
                        $nodes = New-Object System.Collections.ArrayList;
                        $clusterName = $null;
                        $isCluster = $false;
                        $instanceValue = $regKey.GetValue($sqlInstance);
                        $log += "Working with $regPath\$instanceValue on $computer"
                        $instanceReg = $reg.OpenSubKey("$regPath\\$instanceValue");
                        if ($instanceReg.GetSubKeyNames() -contains 'Cluster') {
                            $isCluster = $true;
                            $instanceRegCluster = $instanceReg.OpenSubKey('Cluster');
                            $clusterName = $instanceRegCluster.GetValue('ClusterName');
                            #Write-Message -Level Verbose -Message "Getting cluster node names";
                            $clusterReg = $reg.OpenSubKey("Cluster\\Nodes");
                            $clusterNodes = $clusterReg.GetSubKeyNames();
                            if ($clusterNodes) {
                                foreach ($clusterNode in $clusterNodes) {
                                    $null = $nodes.Add($clusterReg.OpenSubKey($clusterNode).GetValue("NodeName").ToUpper());
                                }
                            }
                        }

                        #region Gather additional information about SQL instance
                        $instanceRegSetup = $instanceReg.OpenSubKey("Setup")

                        #region Get SQL instance directory
                        try {
                            $instanceDir = $instanceRegSetup.GetValue("SqlProgramDir");
                            if (([System.IO.Path]::GetPathRoot($instanceDir) -ne $instanceDir) -and $instanceDir.EndsWith("\")) {
                                $instanceDir = $instanceDir.Substring(0, $instanceDir.Length - 1);
                            }
                        } catch {
                            $instanceDir = $null;
                        }
                        #endregion Get SQL instance directory

                        #region Get SQL edition
                        try {
                            $edition = $instanceRegSetup.GetValue("Edition");
                        } catch {
                            $edition = $null;
                        }
                        #endregion Get SQL edition

                        #region Get resume value
                        try {
                            $resume = [bool][int]$instanceRegSetup.GetValue("Resume");
                        } catch {
                            $resume = $false;
                        }
                        #endregion Get resume value

                        #region Get SQL version
                        $version = $null
                        try {
                            $versionHash = @{
                                '11' = 'SQLServer2012'
                                '12' = 'SQLServer2014'
                                '13' = 'SQLServer2016'
                                '14' = 'SQL2017'
                                '15' = 'SQL2019'
                            }
                            $version = $instanceRegSetup.GetValue("Version");
                            $log += "Found version $version"
                            if ($patchVersion = $instanceRegSetup.GetValue("PatchLevel")) {
                                $log += "Using patch version $patchVersion over $version"
                                $version = $patchVersion
                            }
                            # if patch version is not available - use global reg node to extract the latest patch
                            $majorVersion = $version.Split('.')[0]
                            if (!$patchVersion -and $majorVersion -and $versionHash[$majorVersion]) {
                                $verKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\$($majorVersion)0\\$($versionHash[$majorVersion])\\CurrentVersion")
                                $version = $verKey.GetValue('Version')
                                $log += "New version from the CurrentVersion key: $version"
                            }
                        } catch {
                            $log += "Failed to read one of the reg keys, found version $version so far"
                        }
                        #endregion Get SQL version

                        #region Get exe version
                        try {
                            # attempt to recover a real version of a sqlservr.exe by getting file properties from a remote machine
                            # not sure how to support SSRS/SSAS, as SSDS is the only one that has binary path in the Setup node
                            if ($binRoot = $instanceRegSetup.GetValue("SQLBinRoot")) {
                                $fileVersion = (Get-Item -Path (Join-Path $binRoot "sqlservr.exe") -ErrorAction Stop).VersionInfo.ProductVersion
                                if ($fileVersion) {
                                    $version = $fileVersion
                                    $log += "New version from the binary file: $version"
                                }
                            }
                        } catch {
                            $log += "Failed to get exe version, leaving $version as is"
                        }
                        #endregion Get exe version

                        #endregion Gather additional information about SQL instance

                        #region Generate return object
                        [pscustomobject]@{
                            ComputerName  = $computer.ToUpper();
                            InstanceName  = $sqlInstance;
                            InstanceID    = $instanceValue;
                            InstanceDir   = $instanceDir;
                            Edition       = $edition;
                            Version       = $version;
                            Caption       = {
                                switch -regex ($version) {
                                    "^11" { "SQL Server 2012"; break }
                                    "^10\.5" { "SQL Server 2008 R2"; break }
                                    "^10" { "SQL Server 2008"; break }
                                    "^9" { "SQL Server 2005"; break }
                                    "^8" { "SQL Server 2000"; break }
                                    default { "Unknown"; }
                                }
                            }.InvokeReturnAsIs();
                            IsCluster     = $isCluster;
                            IsClusterNode = ($nodes -contains $computer);
                            ClusterName   = $clusterName;
                            ClusterNodes  = ($nodes -ne $computer);
                            FullName      = {
                                if ($sqlInstance -eq "MSSQLSERVER") {
                                    $computer.ToUpper();
                                } else {
                                    "$($computer.ToUpper())\$($sqlInstance)";
                                }
                            }.InvokeReturnAsIs();
                            Log           = $log
                            Resume        = $resume
                        }
                        #endregion Generate return object
                    }
                    #endregion Process each instance
                }
            }
            $reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Default')
            $baseKeys = "SOFTWARE\\Microsoft\\Microsoft SQL Server", "SOFTWARE\\Wow6432Node\\Microsoft\\Microsoft SQL Server";
            if ($reg.OpenSubKey($baseKeys[0])) {
                $regPath = $baseKeys[0];
            } elseif ($reg.OpenSubKey($baseKeys[1])) {
                $regPath = $baseKeys[1];
            } else {
                throw "Failed to find any regkeys on $env:computername"
            }

            $computer = $Env:COMPUTERNAME

            $regKey = $reg.OpenSubKey("$regPath");
            if ($regKey.GetSubKeyNames() -contains "Instance Names") {
                foreach ($componentName in $Component) {
                    $componentRegKeyName = $componentNameMap |
                        Where-Object { $_.ComponentName -eq $componentName } |
                        Select-Object -ExpandProperty RegKeyName;
                    $regKey = $reg.OpenSubKey("$regPath\\Instance Names\\{0}" -f $componentRegKeyName);
                    if ($regKey) {
                        foreach ($regValueName in $regKey.GetValueNames()) {
                            if ($componentRegKeyName -eq 'RS' -and $regValueName -eq 'PBIRS') { continue } #filtering out Power BI - not supported
                            if ($componentRegKeyName -eq 'RS' -and $regValueName -eq 'SSRS') { continue }  #filtering out SSRS2017+ - not supported
                            $result = Get-SQLInstanceDetail -RegPath $regPath -Reg $reg -RegKey $regKey -Instance $regValueName;
                            $result | Add-Member -Type NoteProperty -Name InstanceType -Value ($componentNameMap | Where-Object { $_.ComponentName -eq $componentName }).DisplayName -PassThru
                        }
                    }
                }
            } elseif ($regKey.GetValueNames() -contains 'InstalledInstances') {
                $isCluster = $false;
                $regKey.GetValue('InstalledInstances') | ForEach-Object {
                    Get-SQLInstanceDetail -RegPath $regPath -Reg $reg -RegKey $regKey -Instance $_
                };
            } else {
                throw "Failed to find any instance names on $env:computername"
            }
        }
    }
    process {
        foreach ($computer in $ComputerName) {
            $arguments = @{ Component = $Component }
            $results = Invoke-Command2 -ComputerName $computer -ScriptBlock $regScript -Credential $Credential -ErrorAction Stop -Raw -ArgumentList $arguments -RequiredPSVersion 3.0

            # Log is stored in the log property, pile it all into the debug log
            foreach ($logEntry in $results.Log) {
                Write-Message -Level Debug -Message $logEntry
            }
            foreach ($result in $results) {
                # If version is unknown that component should be excluded, otherwise it would fail on conversion. We have no use for versionless components anyways.
                if (-Not $result.Version) {
                    Write-Message -Level Warning -Message "Component $($result.InstanceName) on $($result.ComputerName) has an unknown version and was ommitted from the instance list"
                    continue
                }
                # Replace first decimal of the minor build with a 0, since we're using build numbers here
                # Refer to https://sqlserverbuilds.blogspot.com/
                Write-Message -Level Debug -Message "Converting version $($result.Version) to [version]"
                $newVersion = New-Object -TypeName System.Version -ArgumentList ([string]$result.Version)
                $newVersion = New-Object -TypeName System.Version -ArgumentList ($newVersion.Major , ($newVersion.Minor - $newVersion.Minor % 10), $newVersion.Build)
                Write-Message -Level Debug -Message "Converted version $($result.Version) to $newVersion"
                # Find a proper build reference and replace Version property
                $result.Version = Get-DbaBuild -Build $newVersion -EnableException
                $result | Select-Object -ExcludeProperty Log
            }
        }
    }
}
# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB3yLcnuMKNqapb
# 9no3DtLJnpd+sfroSXgTf+MnUhWh8qCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAnX/ffiPauoQ2VDbDEfU+NiP4r
# mYullC+1547cSJxSLDANBgkqhkiG9w0BAQEFAASCAQCJKMbRNs9dtME7soORvCD8
# bOI+nqiYmn6HfJaLbJCnAUa7AU8jN5nQlTru66Otfko25mVruUv8UjoELNRgoxPI
# OhwRgBZUyxFn63pwGh5pveYWQOM0Y6ergMOF6agv0y/+lEH84zXOjW7i/zaRlaA/
# jZCdyCS1LxfC3Lvg2fqt5QIpol0m2ehAkDpW9EJ+qjCkEwa6+vxtFfiTf4cFl3Ov
# oKDZFIn2bJSatHd56gdVXj1LIUCs2xPHjTkHqLKivGzhWMsqemmyWwl2LgEj3l04
# KQ7xFuJvJo73ObqigVUAwiiOqmNR0SmLh1MJTNwBwzBSp4qH6xMEyxwxeRZap2Ye
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIyMTAyMjIwMzgyNlowLwYJKoZIhvcNAQkEMSIE
# IMn8AEizXzgJUl09UVP8nzn75zKBV2C3/5exzH62AhJxMA0GCSqGSIb3DQEBAQUA
# BIICAHLhOWWdpjytNQXPVUZ4c88SCDvvO8iIhxNJe6RuuNnLijdH4LA6DzKmPOTc
# 5PnXz9S53IdbC3/pGWuXdPYfBtszaXnsriAlfdrnr7Of0OINxPcfFwNlUgpfJIa+
# zhn5VnCxqeuNoRHS1sfebFcucqMuWE5JhV1SEOD9a8+u+0DkpBrRHf84Vyh5znF7
# Hw7i1ts9ybQVr0PRmXdT3lgjSYWLqTQF6qSUhEBnR0YpOXMlS6hvyTDv//+tkxf2
# +pQjlif9ElY3wZWSth2wgFuEah0WutMXElh/uXg7DZwJ5zQ78MaLlAMNtq5VeCG/
# O545TaiWJwuxJQ+pOT+vBIWJr6cRuU+eh1jfUZsNIbx+WZ6y4U1T8TC5Btuvp2DC
# FdSguL7rr6tLzwxDn+7W5tOdFyPofF3UT0gYLikjgQxEoJ1uDn3DDRtK8WRFlF6v
# VrnPDZjJmGrOHnkVLluXJHWFlRURBiE99dRvvOieQ/0DtKHUXTb8cRuvfSlh1DeC
# OqgIJBowAZ3oupbKDiZ6Ez54fotcKz0vip3yZ7NkIsEe/TRqEkGEKuhKgWrJZpj+
# yvyYMnBYh8pRavq1zvAfNjT2hmQ3En7T16EKiZAp5uNW13dIjofMdrMX+GHwx4k1
# UKjym+ZtqpI0KLQB5liPESCeLTDkg0R0nG/+zXv6gVLzu8aQ
# SIG # End signature block
