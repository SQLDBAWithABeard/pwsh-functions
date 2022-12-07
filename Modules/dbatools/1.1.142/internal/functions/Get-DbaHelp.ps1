function Get-DbaHelp {
    <#
    .SYNOPSIS
        Massages inline help data to a more useful format

    .DESCRIPTION
        Takes the inline help and outputs a more usable object

    .PARAMETER Name
        The function/command to extract help from

    .PARAMETER OutputAs
        Output format (raw PSObject or MDString)

    .NOTES
    Author: Simone Bizzotto (@niphlod)

    Website: https://dbatools.io
    Copyright: (c) 2018 by dbatools, licensed under MIT
    License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaHelp


    .EXAMPLE
        Get-DbaHelp Get-DbaDatabase

        Parses the inline help from Get-DbaDatabase and outputs the massaged object

    .EXAMPLE
        Get-DbaHelp Get-DbaDatabase -OutputAs "PSObject"

        Parses the inline help from Get-DbaDatabase and outputs the massaged object

    .EXAMPLE
        PS C:\> Get-DbaHelp Get-DbaDatabase -OutputAs "MDString" | Out-File Get-DbaDatabase.md
        PS C:\> & code Get-DbaDatabase.md

        Parses the inline help from Get-DbaDatabase as MarkDown, saves the file and opens it
        via VSCode

    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$Name,

        [ValidateSet("PSObject", "MDString")]
        [string]$OutputAs = "PSObject"
    )

    begin {
        function Get-DbaTrimmedString($Text) {
            return $Text.Trim() -replace '(\r\n){2,}', "`n"
        }

        $tagsRex = ([regex]'(?m)^[\s]{0,15}Tags:(.*)$')
        $authorRex = ([regex]'(?m)^[\s]{0,15}Author:(.*)$')
        $minverRex = ([regex]'(?m)^[\s]{0,15}MinimumVersion:(.*)$')
        $maxverRex = ([regex]'(?m)^[\s]{0,15}MaximumVersion:(.*)$')
        $availability = 'Windows, Linux, macOS'

        function Get-DbaDocsMD($doc_to_render) {
            $rtn = New-Object -TypeName "System.Collections.ArrayList"
            $null = $rtn.Add("# $($doc_to_render.CommandName)" )
            if ($doc_to_render.Author -or $doc_to_render.Availability) {
                $null = $rtn.Add('|  |  |')
                $null = $rtn.Add('| - | - |')
                if ($doc_to_render.Author) {
                    $null = $rtn.Add('|  **Author**  | ' + $doc_to_render.Author.replace('|', ',') + ' |')
                }
                if ($doc_to_render.Availability) {
                    $null = $rtn.Add('| **Availability** | ' + $doc_to_render.Availability + ' |')
                }
                $null = $rtn.Add('')
            }
            $null = $rtn.Add("`n" + '&nbsp;' + "`n")
            if ($doc_to_render.Alias) {
                $null = $rtn.Add('')
                $null = $rtn.Add('*Aliases : ' + $doc_to_render.Alias + '*')
                $null = $rtn.Add('')
            }
            $null = $rtn.Add('## Synopsis')
            $null = $rtn.Add($doc_to_render.Synopsis)
            $null = $rtn.Add('')
            $null = $rtn.Add('## Description')
            $null = $rtn.Add($doc_to_render.Description)
            $null = $rtn.Add('')
            if ($doc_to_render.Syntax) {
                $null = $rtn.Add('## Syntax')
                $null = $rtn.Add('```')
                $splitted_paramsets = @()
                foreach ($val in ($doc_to_render.Syntax -split $doc_to_render.CommandName)) {
                    if ($val) {
                        $splitted_paramsets += $doc_to_render.CommandName + $val
                    }
                }
                foreach ($syntax in $splitted_paramsets) {
                    $x = 0
                    foreach ($val in ($syntax.Replace("`r", '').Replace("`n", '') -split ' \[')) {
                        if ($x -eq 0) {
                            $null = $rtn.Add($val)
                        } else {
                            $null = $rtn.Add('    [' + $val.replace("`n", '').replace("`n", ''))
                        }
                        $x += 1
                    }
                    $null = $rtn.Add('')
                }

                $null = $rtn.Add('```')
                $null = $rtn.Add("`n" + '&nbsp;' + "`n")
            }
            $null = $rtn.Add('')
            $null = $rtn.Add('## Examples')
            $null = $rtn.Add("`n" + '&nbsp;' + "`n")
            $examples = $doc_to_render.Examples.Replace("`r`n", "`n") -replace '(\r\n){2,8}', '\n'
            $examples = $examples.replace("`r", '').split("`n")
            $inside = 0
            foreach ($row in $examples) {
                if ($row -like '*----') {
                    $null = $rtn.Add("");
                    $null = $rtn.Add('#####' + ($row -replace '-{4,}([^-]*)-{4,}', '$1').replace('EXAMPLE', 'Example: '))
                } elseif (($row -like 'PS C:\>*') -or ($row -like '>>*')) {
                    if ($inside -eq 0) { $null = $rtn.Add('```') }
                    $null = $rtn.Add(($row.Trim() -replace 'PS C:\\>\s*', "PS C:\> "))
                    $inside = 1
                } elseif ($row.Trim() -eq '' -or $row.Trim() -eq 'Description') {

                } else {
                    if ($inside -eq 1) {
                        $inside = 0
                        $null = $rtn.Add('```')
                    }
                    $null = $rtn.Add("$row<br>")
                }
            }
            if ($inside -eq 1) {
                $inside = 0
                $null = $rtn.Add('```')
            }
            if ($doc_to_render.Params) {
                $dotitle = 0
                $filteredparams = @()
                foreach ($p in $doc_to_render.Params) {
                    if ($p[3] -eq $true) {
                        $filteredparams += , $p
                    }
                }
                $dotitle = 0
                foreach ($el in $filteredparams) {
                    if ($dotitle -eq 0) {
                        $dotitle = 1
                        $null = $rtn.Add('### Required Parameters')
                    }
                    $null = $rtn.Add('##### -' + $el[0])
                    $null = $rtn.Add($el[1] + '<br>')
                    $null = $rtn.Add('')
                    $null = $rtn.Add('|  |  |')
                    $null = $rtn.Add('| - | - |')
                    $null = $rtn.Add('| Alias | ' + $el[2] + ' |')
                    $null = $rtn.Add('| Required | ' + $el[3] + ' |')
                    $null = $rtn.Add('| Pipeline | ' + $el[4] + ' |')
                    $null = $rtn.Add('| Default Value | ' + $el[5] + ' |')
                    if ($el[6]) {
                        $null = $rtn.Add('| Accepted Values | ' + $el[6] + ' |')
                    }
                    $null = $rtn.Add('')
                }
                $dotitle = 0
                $filteredparams = @()
                foreach ($p in $doc_to_render.Params) {
                    if ($p[3] -eq $false) {
                        $filteredparams += , $p
                    }
                }
                foreach ($el in $filteredparams) {
                    if ($dotitle -eq 0) {
                        $dotitle = 1
                        $null = $rtn.Add('### Optional Parameters')
                    }

                    $null = $rtn.Add('##### -' + $el[0])
                    $null = $rtn.Add($el[1] + '<br>')
                    $null = $rtn.Add('')
                    $null = $rtn.Add('|  |  |')
                    $null = $rtn.Add('| - | - |')
                    $null = $rtn.Add('| Alias | ' + $el[2] + ' |')
                    $null = $rtn.Add('| Required | ' + $el[3] + ' |')
                    $null = $rtn.Add('| Pipeline | ' + $el[4] + ' |')
                    $null = $rtn.Add('| Default Value | ' + $el[5] + ' |')
                    if ($el[6]) {
                        $null = $rtn.Add('| Accepted Values | ' + $el[6] + ' |')
                    }
                    $null = $rtn.Add('')
                }
            }
            $null = $rtn.Add('')
            $null = $rtn.Add("`n" + '&nbsp;' + "`n")
            $null = $rtn.Add('Want to see the source code for this command? Check out [' + $doc_to_render.CommandName + '](https://github.com/dataplat/dbatools/blob/master/functions/' + $doc_to_render.CommandName + '.ps1) on GitHub.')
            $null = $rtn.Add("<br>")
            $null = $rtn.Add('Want to see the Bill Of Health for this command? Check out [' + $doc_to_render.CommandName + '](https://dataplat.github.io/boh#' + $doc_to_render.CommandName + ').')
            $null = $rtn.Add('')

            return $rtn
        }


    }
    process {

        if ($Name -in $script:noncoresmo -or $Name -in $script:windowsonly) {
            $availability = 'Windows only'
        }
        try {
            $thishelp = Get-Help $Name -Full
        } catch {
            Stop-Function -Message "Issue getting help for $Name" -Target $Name -ErrorRecord $_ -Continue
        }

        $thebase = @{ }
        $thebase.CommandName = $Name
        $thebase.Name = $thishelp.Name

        $thebase.Availability = $availability

        $alias = Get-Alias -Definition $Name -ErrorAction SilentlyContinue
        $thebase.Alias = $alias.Name -Join ','

        ## fetch the description
        $thebase.Description = $thishelp.Description.Text

        ## fetch examples
        $thebase.Examples = Get-DbaTrimmedString -Text ($thishelp.Examples | Out-String -Width 200)

        ## fetch help link
        $thebase.Links = ($thishelp.relatedLinks).NavigationLink.Uri

        ## fetch the synopsis
        $thebase.Synopsis = $thishelp.Synopsis

        ## fetch the syntax
        $thebase.Syntax = Get-DbaTrimmedString -Text ($thishelp.Syntax | Out-String -Width 600)

        ## store notes
        $as = $thishelp.AlertSet | Out-String -Width 600

        ## fetch the tags
        $tags = $tagsrex.Match($as).Groups[1].Value
        if ($tags) {
            $thebase.Tags = $tags.Split(',').Trim()
        }
        ## fetch the author
        $author = $authorRex.Match($as).Groups[1].Value
        if ($author) {
            $thebase.Author = $author.Trim()
        }

        ## fetch MinimumVersion
        $MinimumVersion = $minverRex.Match($as).Groups[1].Value
        if ($MinimumVersion) {
            $thebase.MinimumVersion = $MinimumVersion.Trim()
        }

        ## fetch MaximumVersion
        $MaximumVersion = $maxverRex.Match($as).Groups[1].Value
        if ($MaximumVersion) {
            $thebase.MaximumVersion = $MaximumVersion.Trim()
        }

        ## fetch Parameters
        $parameters = $thishelp.parameters.parameter
        $command = Get-Command $Name
        $params = @()
        foreach ($p in $parameters) {
            $paramAlias = $command.parameters[$p.Name].Aliases
            $validValues = $command.parameters[$p.Name].Attributes.ValidValues -Join ','
            $paramDescr = Get-DbaTrimmedString -Text ($p.Description | Out-String -Width 200)
            $params += , @($p.Name, $paramDescr, ($paramAlias -Join ','), ($p.Required -eq $true), $p.PipelineInput, $p.DefaultValue, $validValues)
        }

        $thebase.Params = $params

        if ($thebase.CommandName -eq "Select-DbaObject") {
            $thebase.Synopsis = "Wrapper around Select-Object, extends property parameter."
            $thebase.Author = "Friedrich Weinmann (@FredWeinmann)"
            $thebase.Description = "Wrapper around Select-Object, extends property parameter.

            This function allows specifying in-line transformation of the properties specified without needing to use complex hashtables.
            For example, renaming a property becomes as simple as 'Length as Size'

            Also supported:

            - Specifying a typename

            - Picking the default display properties

            - Adding to an existing object without destroying its type

            See the description of the Property parameter for an exhaustive list of legal notations for in-line transformations."
            $thebase.Examples = '    ---------------- Example 1: Renaming a property ----------------
            Get-ChildItem | Select-DbaObject Name, "Length as Size"

            Selects the properties Name and Length, renaming Length to Size in the process.

            ------------------ Example 2: Converting type ------------------

            Import-Csv .\file.csv | Select-DbaObject Name, "Length as Size to DbaSize"

            Selects the properties Name and Length, renaming Length to Size and converting it to [DbaSize] (a userfriendly representation of
            size numbers contained in the dbatools module)

            ---------- Example 3: Selecting from another object 1 ----------

            $obj = [PSCustomObject]@{ Name = "Foo" }
            Get-ChildItem | Select-DbaObject FullName, Length, "Name from obj"

            Selects the properties FullName and Length from the input and the Name property from the object stored in $obj

            ---------- Example 4: Selecting from another object 2 ----------

            $list = @()
            $list += [PSCustomObject]@{ Type = "Foo"; ID = 1 }
            $list += [PSCustomObject]@{ Type = "Bar"; ID = 2 }
            $obj | Select-DbaObject Name, "ID from list WHERE Type = Name"

            This allows you to LEFT JOIN contents of another variable. Note that it can only do simple property-matching at this point.

            It will select Name from the objects stored in $obj, and for each of those the ID Property on any object in $list that has a
            Type property of equal value as Name on the input.

            ---------------- Example 5: Naming and styling ----------------

            Get-ChildItem | Select-DbaObject Name, Length, FullName, Used, LastWriteTime, Mode -TypeName MyType -ShowExcludeProperty Mode,
            Used

            Lists all items in the current path, selects the properties specified (whether they exist or not) , then ...

            - Sets the name to "MyType"

            - Hides the properties "Mode" and "Used" from the default display set, causing them to be hidden from default view'
            $thebase.Syntax = "Select-DbaObject [-Property <DbaSelectParameter[]>] [-Alias <SelectAliasParameter[]>] [-ScriptProperty <SelectScriptPropertyParameter[]>] [-ScriptMethod <SelectScriptMethodParameter[]>] [-InputObject ] [-ExcludeProperty <string[]>] [-ExpandProperty ] -Unique [-Last ] [-First ] [-Skip ] -Wait [-ShowProperty <string[]>] [-ShowExcludeProperty <string[]>] [-TypeName ] -KeepInputObject []

            Select-DbaObject [-Property <DbaSelectParameter[]>] [-Alias <SelectAliasParameter[]>] [-ScriptProperty <SelectScriptPropertyParameter[]>] [-ScriptMethod <SelectScriptMethodParameter[]>] [-InputObject ] [-ExcludeProperty <string[]>] [-ExpandProperty ] -Unique [-SkipLast ] [-ShowProperty <string[]>] [-ShowExcludeProperty <string[]>] [-TypeName ] -KeepInputObject []

            Select-DbaObject [-InputObject ] -Unique -Wait [-Index <int[]>] [-ShowProperty <string[]>] [-ShowExcludeProperty <string[]>] [-TypeName ] -KeepInputObject []"
        }

        if ($thebase.CommandName -eq "Set-DbatoolsConfig") {
            $thebase.Name = "Set-DbatoolsConfig"
            $thebase.CommandName = "Set-DbatoolsConfig"
            $thebase.Synopsis = 'Sets configuration entries.'
            $thebase.Author = "Friedrich Weinmann (@FredWeinmann)"
            $thebase.Description = 'This function creates or changes configuration values. These can be used to provide dynamic configuration information outside the PowerShell variable system.'
            $thebase.Examples = '---------------------- Example 1: Simple ----------------------
            C:\PS> Set-DbatoolsConfig -FullName Path.DbatoolsData -Value E:\temp\dbatools

            Updates the configuration entry for Path.DbatoolsData to E:\temp\dbatools'
            $thebase.Syntax = 'Set-DbatoolsConfig -FullName <String> [-Value <Object>] [-Description <String>] [-Validation <String>] [-Handler <ScriptBlock>]
            [-Hidden] [-Default] [-Initialize] [-DisableValidation] [-DisableHandler] [-EnableException] [-SimpleExport] [-ModuleExport]
            [-PassThru] [-AllowDelete] [<CommonParameters>]

            Set-DbatoolsConfig -FullName <String> [-Description <String>] [-Validation <String>] [-Handler <ScriptBlock>] [-Hidden]
            [-Default] [-Initialize] [-DisableValidation] [-DisableHandler] [-EnableException] -PersistedValue <String> [-PersistedType
            <ConfigurationValueType>] [-SimpleExport] [-ModuleExport] [-PassThru] [-AllowDelete] [<CommonParameters>]

            Set-DbatoolsConfig -Name <String> [-Module <String>] [-Value <Object>] [-Description <String>] [-Validation <String>] [-Handler
            <ScriptBlock>] [-Hidden] [-Default] [-Initialize] [-DisableValidation] [-DisableHandler] [-EnableException] [-SimpleExport]
            [-ModuleExport] [-PassThru] [-AllowDelete] [<CommonParameters>]'
        }
        if ($OutputAs -eq "PSObject") {
            [pscustomobject]$thebase
        } elseif ($OutputAs -eq "MDString") {
            Get-DbaDocsMD -doc_to_render $thebase
        }

    }
    end {

    }
}
# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBFucl3fVGxkBV6
# zX2o2SPKX55tyPHo/fqj52Vz4Krj66CCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBkLHO6oLBcqHiyYAmf4y/FbXZj
# JMY5kBHpn/QPYQ9gozANBgkqhkiG9w0BAQEFAASCAQCbO8ujds7OGr69Rl24yxxl
# Sgp5S30HtVAP2FU8dpj352+n6uGHT3/HG2OBQb+Tb//a5Wlvp2H5F497eJMoUIgN
# 6WtlzX6ywymmKS3hVDFaCzV06GiaKPoaFjGQgz2Ocej/AIyuwkEHrtU4a0mlcWZZ
# qtMCrEXLkULBlOxE1G0Fi/T/o5G38LDOksyCjuQF5GRsjGozo8oAoUJgjRaXMyab
# gPc9dzuVe8dlvvmH8llNNEauFJPW/KM6098CFgQ/cRR6jKCexzZFFN7cZiSuRpEk
# jf+3oQppuECbUMgb5Sc2yw+dRR05I0gzo9ivO6urU3LNBYjZEnT+yx05oDfGg0Px
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIyMTAyMjIwMzgyNFowLwYJKoZIhvcNAQkEMSIE
# IAWq8O4E/sIx2cpPiH2iQ9OeCwb+KGibNhjXcZWUHQxiMA0GCSqGSIb3DQEBAQUA
# BIICAGqvgbwtadFsJJTzQYNUqVw/u5CnTDDSvLXTKT8sCP/abaSoeiYo54fm1r8F
# ZQpJdxvZHaqU4cMZDbqZ8nIfUtK0cyhPcE2wj2XOGm8Wf8ABCWMlwcTwUAQbXBT/
# 2d5dsN9qYfRx22L95bm4N3c9QPHuK6t25whHH8PHaJZ3PUa3nI1n4hlj752S6bml
# eQnnesasOPwqtaIzmrGwWW6epqiinG8ZiMKr4J5SxagqfSwfzVE173IMBopAE7ok
# P3oMfr/984QTC/owU6WW8tz1DCC6uc61NcgCCpIRA58RBUJaCn2X1B85cCxdy2nP
# JDuHkUnsTX5OHXz5vLtuT9Ks3I+RQR2YBpYsv56m4cZPyc5TjykZFfE1WvH4EpMf
# xFDNoUWQrFzirw4w6fzn/zOgbM+XY7NdTgxwYwXCpm37j9OWJa26yLOX+bJjDB3h
# i9hWfNiuK6IMwdNs6VmJIHakJKF3Pwb/sWVhu4eu2AbU1p6LZx9UGBTBgvAMxdBR
# 43OYXbd1aLiVJLh3Gl7P/DsHrOCmF4Bof+zMcFNeqm1HeHSaYGywifOwb1DULouI
# uL7EM7lKpJq5CuL0orBdPgoZMMHP4SaapCFXkKDHLl17FhJiQYbwtX5zXVya9rqo
# qBfvF6ge1Nm+uYQcnTxJL4hgbrMCJkUJyInoxGY8H8pJbvUO
# SIG # End signature block
