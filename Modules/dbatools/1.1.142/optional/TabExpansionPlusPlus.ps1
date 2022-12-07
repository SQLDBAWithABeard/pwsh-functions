if (-not $ExecutionContext.SessionState.InvokeCommand.GetCommand('Register-ArgumentCompleter','Function,Cmdlet')) {

    #############################################################################
    #
    # TabExpansionPlusPlus
    #
    #

    <#
Copyright (c) 2013, Jason Shirk
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

    #>

    # Save off the previous tab completion so it can be restored if this module
    # is removed.
    $oldTabExpansion = $function:TabExpansion
    $oldTabExpansion2 = $function:TabExpansion2

    [bool]$updatedTypeData = $false


    #region Exported utility functions for completers

    #############################################################################
    #
    # Helper function to create a new completion results
    #
    function New-CompletionResult {
        param ([Parameter(ValueFromPipelineByPropertyName, Mandatory, ValueFromPipeline)]
            [ValidateNotNullOrEmpty()]
            [string]
            $CompletionText,

            [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
            [string]
            $ToolTip,

            [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
            [string]
            $ListItemText,

            [System.Management.Automation.CompletionResultType]
            $CompletionResultType = [System.Management.Automation.CompletionResultType]::ParameterValue,

            [switch]
            $NoQuotes = $false
        )

        process {
            $toolTipToUse = if ($ToolTip -eq '') { $CompletionText }
            else { $ToolTip }
            $listItemToUse = if ($ListItemText -eq '') { $CompletionText }
            else { $ListItemText }

            # If the caller explicitly requests that quotes
            # not be included, via the -NoQuotes parameter,
            # then skip adding quotes.

            if ($CompletionResultType -eq [System.Management.Automation.CompletionResultType]::ParameterValue -and -not $NoQuotes) {
                # Add single quotes for the caller in case they are needed.
                # We use the parser to robustly determine how it will treat
                # the argument.  If we end up with too many tokens, or if
                # the parser found something expandable in the results, we
                # know quotes are needed.

                $tokens = $null
                $null = [System.Management.Automation.Language.Parser]::ParseInput("echo $CompletionText", [ref]$tokens, [ref]$null)
                if ($tokens.Length -ne 3 -or
                    ($tokens[1] -is [System.Management.Automation.Language.StringExpandableToken] -and
                        $tokens[1].Kind -eq [System.Management.Automation.Language.TokenKind]::Generic)) {
                    $CompletionText = "'$CompletionText'"
                }
            }
            return New-Object System.Management.Automation.CompletionResult `
            ($CompletionText, $listItemToUse, $CompletionResultType, $toolTipToUse.Trim())
        }

    }

    #############################################################################
    #
    # .SYNOPSIS
    #
    #     This is a simple wrapper of Get-Command gets commands with a given
    #     parameter ignoring commands that use the parameter name as an alias.
    #
    function Get-CommandWithParameter {
        [CmdletBinding(DefaultParameterSetName = 'AllCommandSet')]
        param (
            [Parameter(ParameterSetName = 'AllCommandSet', ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [ValidateNotNullOrEmpty()]
            [string[]]
            ${Name},

            [Parameter(ParameterSetName = 'CmdletSet', ValueFromPipelineByPropertyName)]
            [string[]]
            ${Verb},

            [Parameter(ParameterSetName = 'CmdletSet', ValueFromPipelineByPropertyName)]
            [string[]]
            ${Noun},

            [Parameter(ValueFromPipelineByPropertyName)]
            [string[]]
            ${Module},

            [ValidateNotNullOrEmpty()]
            [Parameter(Mandatory)]
            [string]
            ${ParameterName})

        begin {
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Command', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = { & $wrappedCmd @PSBoundParameters | Where-Object { $_.Parameters[$ParameterName] -ne $null } }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        }
        process {
            $steppablePipeline.Process($_)
        }
        end {
            $steppablePipeline.End()
        }
    }

    #############################################################################
    #
    function Set-CompletionPrivateData {
        param (
            [ValidateNotNullOrEmpty()]
            [string]
            $Key,

            [object]
            $Value,

            [ValidateNotNullOrEmpty()]
            [int]
            $ExpirationSeconds = 604800
        )

        $Cache = [PSCustomObject]@{
            Value          = $Value
            ExpirationTime = (Get-Date).AddSeconds($ExpirationSeconds)
        }
        $completionPrivateData[$key] = $Cache
    }

    #############################################################################
    #
    function Get-CompletionPrivateData {
        param (
            [ValidateNotNullOrEmpty()]
            [string]
            $Key)

        if (!$Key)
        { return $completionPrivateData }

        $cacheValue = $completionPrivateData[$key]
        if ((Get-Date) -lt $cacheValue.ExpirationTime) {
            return $cacheValue.Value
        }
    }

    #############################################################################
    #
    function Get-CompletionWithExtension {
        param ([string]
            $lastWord,

            [string[]]
            $extensions)

        [System.Management.Automation.CompletionCompleters]::CompleteFilename($lastWord) |
            Where-Object {
            # Use ListItemText because it won't be quoted, CompletionText might be
            [System.IO.Path]::GetExtension($_.ListItemText) -in $extensions
        }
    }

    #############################################################################
    #
    function New-CommandTree {
        [CmdletBinding(DefaultParameterSetName = 'Default')]
        param (
            [Parameter(Mandatory, ParameterSetName = 'Default')]
            [Parameter(Mandatory, ParameterSetName = 'Argument')]
            [ValidateNotNullOrEmpty()]
            [string]
            $Completion,

            [Parameter(Position = 1, Mandatory, ParameterSetName = 'Default')]
            [Parameter(Position = 1, Mandatory, ParameterSetName = 'Argument')]
            [string]
            $Tooltip,

            [Parameter(ParameterSetName = 'Argument')]
            [switch]
            $Argument,

            [Parameter(Position = 2, ParameterSetName = 'Default')]
            [Parameter(Position = 1, ParameterSetName = 'ScriptBlockSet')]
            [scriptblock]
            $SubCommands,

            [Parameter(Mandatory, ParameterSetName = 'ScriptBlockSet')]
            [scriptblock]
            $CompletionGenerator
        )

        $actualSubCommands = $null
        if ($null -ne $SubCommands) {
            $actualSubCommands = [NativeCommandTreeNode[]](& $SubCommands)
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Default' {
                New-Object NativeCommandTreeNode $Completion, $Tooltip, $actualSubCommands
                break
            }
            'Argument' {
                New-Object NativeCommandTreeNode $Completion, $Tooltip, $true
            }
            'ScriptBlockSet' {
                New-Object NativeCommandTreeNode $CompletionGenerator, $actualSubCommands
                break
            }
        }
    }

    #############################################################################
    #
    function Get-CommandTreeCompletion {
        param ($wordToComplete,

            $commandAst,

            [NativeCommandTreeNode[]]
            $CommandTree)

        $commandElements = $commandAst.CommandElements

        # Skip the first command element - it's the command name
        # Iterate through the remaining elements, stopping early
        # if we find the element that matches $wordToComplete.
        for ($i = 1; $i -lt $commandElements.Count; $i++) {
            if (!($commandElements[$i] -is [System.Management.Automation.Language.StringConstantExpressionAst])) {
                # Ignore arguments that are expressions.  In some rare cases this
                # could cause strange completions because the context is incorrect, e.g.:
                #    $c = 'advfirewall'
                #    netsh $c firewall
                # Here we would be in advfirewall firewall context, but we'd complete as
                # though we were in firewall context.
                continue
            }

            if ($commandElements[$i].Value -eq $wordToComplete) {
                $CommandTree = $CommandTree |
                    Where-Object { $_.Command -like "$wordToComplete*" -or $_.CompletionGenerator -ne $null }
                break
            }

            foreach ($subCommand in $CommandTree) {
                if ($subCommand.Command -eq $commandElements[$i].Value) {
                    if (!$subCommand.Argument) {
                        $CommandTree = $subCommand.SubCommands
                    }
                    break
                }
            }
        }

        if ($null -ne $CommandTree) {
            $CommandTree | ForEach-Object {
                if ($_.Command) {
                    $toolTip = if ($_.Tooltip) { $_.Tooltip }
                    else { $_.Command }
                    New-CompletionResult -CompletionText $_.Command -ToolTip $toolTip
                } else {
                    & $_.CompletionGenerator $wordToComplete $commandAst
                }
            }
        }
    }

    #endregion Exported utility functions for completers

    #region Exported functions

    #############################################################################
    #
    # .SYNOPSIS
    #     Register a ScriptBlock to perform argument completion for a
    #     given command or parameter.
    #
    # .DESCRIPTION
    #     Argument completion can be extended without needing to do any
    #     parsing in many cases. By registering a handler for specific
    #     commands and/or parameters, PowerShell will call the handler
    #     when appropriate.
    #
    #     There are 2 kinds of extensions - native and PowerShell. Native
    #     refers to commands external to PowerShell, e.g. net.exe. PowerShell
    #     completion covers any functions, scripts, or cmdlets where PowerShell
    #     can determine the correct parameter being completed.
    #
    #     When registering a native handler, you must specify the CommandName
    #     parameter. The CommandName is typically specified without any path
    #     or extension. If specifying a path and/or an extension, completion
    #     will only work when the command is specified that way when requesting
    #     completion.
    #
    #     When registering a PowerShell handler, you must specify the
    #     ParameterName parameter. The CommandName is optional - PowerShell will
    #     first try to find a handler based on the command and parameter, but
    #     if none is found, then it will try just the parameter name. This way,
    #     you could specify a handler for all commands that have a specific
    #     parameter.
    #
    #     A handler needs to return instances of
    #     System.Management.Automation.CompletionResult.
    #
    #     A native handler is passed 2 parameters:
    #
    #         param($wordToComplete, $commandAst)
    #
    #     $wordToComplete  - The argument being completed, possibly an empty string
    #     $commandAst      - The ast of the command being completed.
    #
    #     A PowerShell handler is passed 5 parameters:
    #
    #         param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    #
    #     $commandName        - The command name
    #     $parameterName      - The parameter name
    #     $wordToComplete     - The argument being completed, possibly an empty string
    #     $commandAst         - The parsed representation of the command being completed.
    #     $fakeBoundParameter - Like $PSBoundParameters, contains values for some of the parameters.
    #                           Certain values are not included, this does not mean a parameter was
    #                           not specified, just that getting the value could have had unintended
    #                           side effects, so no value was computed.
    #
    # .PARAMETER ParameterName
    #     The name of the parameter that the Completion parameter supports.
    #     This parameter is not supported for native completion and is
    #     mandatory for script completion.
    #
    # .PARAMETER CommandName
    #     The name of the command that the Completion parameter supports.
    #     This parameter is mandatory for native completion and is optional
    #     for script completion.
    #
    # .PARAMETER Completion
    #     A ScriptBlock that returns instances of CompletionResult. For
    #     native completion, the script block parameters are
    #
    #         param($wordToComplete, $commandAst)
    #
    #     For script completion, the parameters are:
    #
    #         param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    #
    # .PARAMETER Description
    #     A description of how the completion can be used.
    #
    function Register-ArgumentCompleter {
        [CmdletBinding(DefaultParameterSetName = "PowerShellSet")]
        param (
            [Parameter(ParameterSetName = "NativeSet", Mandatory)]
            [Parameter(ParameterSetName = "PowerShellSet")]
            [string[]]
            $CommandName = "",

            [Parameter(ParameterSetName = "PowerShellSet", Mandatory)]
            [string]
            $ParameterName = "",

            [Parameter(Mandatory)]
            [scriptblock]
            $ScriptBlock,

            [string]
            $Description,

            [Parameter(ParameterSetName = "NativeSet")]
            [switch]
            $Native)

        $fnDefn = $ScriptBlock.Ast -as [System.Management.Automation.Language.FunctionDefinitionAst]
        if (!$Description) {
            # See if the script block is really a function, if so, use the function name.
            $Description = if ($fnDefn -ne $null) { $fnDefn.Name }
            else { "" }
        }

        if ($MyInvocation.ScriptName -ne (& { $MyInvocation.ScriptName })) {
            # Make an unbound copy of the script block so it has access to TabExpansionPlusPlus when invoked.
            # We can skip this step if we created the script block (Register-ArgumentCompleter was
            # called internally).
            if ($fnDefn -ne $null) {
                $ScriptBlock = $ScriptBlock.Ast.Body.GetScriptBlock() # Don't reparse, just get a new ScriptBlock.
            } else {
                $ScriptBlock = $ScriptBlock.Ast.GetScriptBlock() # Don't reparse, just get a new ScriptBlock.
            }
        }

        foreach ($command in $CommandName) {
            if ($command -and $ParameterName) {
                $command += ":"
            }

            $key = if ($Native) { 'NativeArgumentCompleters' }
            else { 'CustomArgumentCompleters' }
            $tabExpansionOptions[$key]["${command}${ParameterName}"] = $ScriptBlock

            $tabExpansionDescriptions["${command}${ParameterName}$Native"] = $Description
        }
    }

    #############################################################################
    #
    # .SYNOPSIS
    #     Tests the registered argument completer
    #
    # .DESCRIPTION
    #     Invokes the registered parameteter completer for a specified command to make it easier to test
    #     a completer
    #
    # .EXAMPLE
    #  Test-ArgumentCompleter -CommandName Get-Verb -ParameterName Verb -WordToComplete Sta
    #
    # Test what would be completed if Get-Verb -Verb Sta<Tab> was typed at the prompt
    #
    # .EXAMPLE
    #  Test-ArgumentCompleter -NativeCommand Robocopy -WordToComplete /
    #
    # Test what would be completed if Robocopy /<Tab> was typed at the prompt
    #
    function Test-ArgumentCompleter {
        [CmdletBinding(DefaultParametersetName = 'PS')]
        param
        (
            [Parameter(Mandatory, Position = 1, ParameterSetName = 'PS')]
            [string]
            $CommandName
            ,

            [Parameter(Mandatory, Position = 2, ParameterSetName = 'PS')]
            [string]
            $ParameterName
            ,

            [Parameter(ParameterSetName = 'PS')]
            [System.Management.Automation.Language.CommandAst]
            $commandAst
            ,

            [Parameter(ParameterSetName = 'PS')]
            [Hashtable]
            $FakeBoundParameters = @{ }
            ,

            [Parameter(Mandatory, Position = 1, ParameterSetName = 'NativeCommand')]
            [string]
            $NativeCommand
            ,

            [Parameter(Position = 2, ParameterSetName = 'NativeCommand')]
            [Parameter(Position = 3, ParameterSetName = 'PS')]
            [string]
            $WordToComplete = ''

        )

        if ($PSCmdlet.ParameterSetName -eq 'NativeCommand') {
            $Tokens = $null
            $Errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($NativeCommand, [ref]$Tokens, [ref]$Errors)
            $commandAst = $ast.EndBlock.Statements[0].PipelineElements[0]
            $command = $commandAst.GetCommandName()
            $completer = $tabExpansionOptions.NativeArgumentCompleters[$command]
            if (-not $Completer) {
                throw "No argument completer registered for command '$Command' (from $NativeCommand)"
            }
            & $completer $WordToComplete $commandAst
        } else {
            $completer = $tabExpansionOptions.CustomArgumentCompleters["${CommandName}:$ParameterName"]
            if (-not $Completer) {
                throw "No argument completer registered for '${CommandName}:$ParameterName'"
            }
            & $completer $CommandName $ParameterName $WordToComplete $commandAst $FakeBoundParameters
        }
    }

    #############################################################################
    #
    # .SYNOPSIS
    # Retrieves a list of argument completers that have been loaded into the
    # PowerShell session.
    #
    # .PARAMETER Name
    # The name of the argument complete to retrieve. This parameter supports
    # wildcards (asterisk).
    #
    # .EXAMPLE
    # Get-ArgumentCompleter -Name *Azure*;
    function Get-ArgumentCompleter {
        [CmdletBinding()]
        param ([string[]]
            $Name = '*')

        if (!$updatedTypeData) {
            # Define the default display properties for the objects returned by Get-ArgumentCompleter
            [string[]]$properties = "Command", "Parameter"
            Update-TypeData -TypeName 'TabExpansionPlusPlus.ArgumentCompleter' -DefaultDisplayPropertySet $properties -Force
            $updatedTypeData = $true
        }

        function WriteCompleters {
            function WriteCompleter($command, $parameter, $native, $scriptblock) {
                foreach ($n in $Name) {
                    if ($command -like $n) {
                        $c = $command
                        if ($command -and $parameter) { $c += ':' }
                        $description = $tabExpansionDescriptions["${c}${parameter}${native}"]
                        $completer = [pscustomobject]@{
                            Command     = $command
                            Parameter   = $parameter
                            Native      = $native
                            Description = $description
                            ScriptBlock = $scriptblock
                            File        = if ($scriptblock.File) { Split-Path -Leaf -Path $scriptblock.File }
                        }

                        $completer.PSTypeNames.Add('TabExpansionPlusPlus.ArgumentCompleter')
                        Write-Output $completer

                        break
                    }
                }
            }

            foreach ($pair in $tabExpansionOptions.CustomArgumentCompleters.GetEnumerator()) {
                if ($pair.Key -match '^(.*):(.*)$') {
                    $command = $matches[1]
                    $parameter = $matches[2]
                } else {
                    $parameter = $pair.Key
                    $command = ""
                }

                WriteCompleter $command $parameter $false $pair.Value
            }

            foreach ($pair in $tabExpansionOptions.NativeArgumentCompleters.GetEnumerator()) {
                WriteCompleter $pair.Key '' $true $pair.Value
            }
        }

        WriteCompleters | Sort-Object -Property Native, Command, Parameter
    }

    #############################################################################
    #
    # .SYNOPSIS
    #     Register a ScriptBlock to perform argument completion for a
    #     given command or parameter.
    #
    # .DESCRIPTION
    #
    # .PARAMETER Option
    #
    #     The name of the option.
    #
    # .PARAMETER Value
    #
    #     The value to set for Option. Typically this will be $true.
    #
    function Set-TabExpansionOption {
        param (
            [ValidateSet('ExcludeHiddenFiles',
                'RelativePaths',
                'LiteralPaths',
                'IgnoreHiddenShares',
                'AppendBackslash')]
            [string]
            $Option,

            [object]
            $Value = $true)

        $tabExpansionOptions[$option] = $value
    }

    #endregion Exported functions

    #region Internal utility functions

    #############################################################################
    #
    # This function checks if an attribute argument's name can be completed.
    # For example:
    #     [Parameter(<TAB>
    #     [Parameter(Po<TAB>
    #     [CmdletBinding(DefaultPa<TAB>
    #
    function TryAttributeArgumentCompletion {
        param (
            [System.Management.Automation.Language.Ast]
            $ast,

            [int]
            $offset
        )

        $results = @()
        $matchIndex = -1

        try {
            # We want to find any NamedAttributeArgumentAst objects where the Ast extent includes $offset
            $offsetInExtentPredicate = {
                param ($ast)
                return $offset -gt $ast.Extent.StartOffset -and
                $offset -le $ast.Extent.EndOffset
            }
            $asts = $ast.FindAll($offsetInExtentPredicate, $true)

            $attributeType = $null
            $attributeArgumentName = ""
            $replacementIndex = $offset
            $replacementLength = 0

            $attributeArg = $asts | Where-Object { $_ -is [System.Management.Automation.Language.NamedAttributeArgumentAst] } | Select-Object -First 1
            if ($null -ne $attributeArg) {
                $attributeAst = [System.Management.Automation.Language.AttributeAst]$attributeArg.Parent
                $attributeType = $attributeAst.TypeName.GetReflectionAttributeType()
                $attributeArgumentName = $attributeArg.ArgumentName
                $replacementIndex = $attributeArg.Extent.StartOffset
                $replacementLength = $attributeArg.ArgumentName.Length
            } else {
                $attributeAst = $asts | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] } | Select-Object -First 1
                if ($null -ne $attributeAst) {
                    $attributeType = $attributeAst.TypeName.GetReflectionAttributeType()
                }
            }

            if ($null -ne $attributeType) {
                $results = $attributeType.GetProperties('Public,Instance') |
                    Where-Object {
                    # Ignore TypeId (all attributes inherit it)
                    $_.Name -like "$attributeArgumentName*" -and $_.Name -ne 'TypeId'
                } |
                    Sort-Object -Property Name |
                    ForEach-Object {
                    $propType = [Microsoft.PowerShell.ToStringCodeMethods]::Type($_.PropertyType)
                    $propName = $_.Name
                    New-CompletionResult $propName -ToolTip "$propType $propName" -CompletionResultType Property
                }

                return [PSCustomObject]@{
                    Results           = $results
                    ReplacementIndex  = $replacementIndex
                    ReplacementLength = $replacementLength
                }
            }
        } catch { }
    }

    #############################################################################
    #
    # This function completes native commands options starting with - or --
    # works around a bug in PowerShell that causes it to not complete
    # native command options starting with - or --
    #
    function TryNativeCommandOptionCompletion {
        param (
            [System.Management.Automation.Language.Ast]
            $ast,

            [int]
            $offset
        )

        $results = @()
        $replacementIndex = $offset
        $replacementLength = 0
        try {
            # We want to find any Command element objects where the Ast extent includes $offset
            $offsetInOptionExtentPredicate = {
                param ($ast)
                return $offset -gt $ast.Extent.StartOffset -and
                $offset -le $ast.Extent.EndOffset -and
                $ast.Extent.Text.StartsWith('-')
            }
            $option = $ast.Find($offsetInOptionExtentPredicate, $true)
            if ($option -ne $null) {
                $command = $option.Parent -as [System.Management.Automation.Language.CommandAst]
                if ($command -ne $null) {
                    $nativeCommand = [System.IO.Path]::GetFileNameWithoutExtension($command.CommandElements[0].Value)
                    $nativeCompleter = $tabExpansionOptions.NativeArgumentCompleters[$nativeCommand]

                    if ($nativeCompleter) {
                        $results = @(& $nativeCompleter $option.ToString() $command)
                        if ($results.Count -gt 0) {
                            $replacementIndex = $option.Extent.StartOffset
                            $replacementLength = $option.Extent.Text.Length
                        }
                    }
                }
            }
        } catch { }

        return [PSCustomObject]@{
            Results           = $results
            ReplacementIndex  = $replacementIndex
            ReplacementLength = $replacementLength
        }
    }


    #endregion Internal utility functions

    #############################################################################
    #
    # This function is partly a copy of the V3 TabExpansion2, adding a few
    # capabilities such as completing attribute arguments and excluding hidden
    # files from results.
    #
    function global:TabExpansion2 {
        [CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
        param (
            [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 0)]
            [string]
            $inputScript,

            [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 1)]
            [int]
            $cursorColumn,

            [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 0)]
            [System.Management.Automation.Language.Ast]
            $ast,

            [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 1)]
            [System.Management.Automation.Language.Token[]]
            $tokens,

            [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 2)]
            [System.Management.Automation.Language.IScriptPosition]
            $positionOfCursor,

            [Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
            [Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
            [Hashtable]
            $options = $null
        )

        if ($null -ne $options) {
            $options += $tabExpansionOptions
        } else {
            $options = $tabExpansionOptions
        }

        if ($psCmdlet.ParameterSetName -eq 'ScriptInputSet') {
            $results = [System.Management.Automation.CommandCompletion]::CompleteInput(
                <#inputScript#>                $inputScript,
                <#cursorColumn#>                $cursorColumn,
                <#options#>                $options)
        } else {
            $results = [System.Management.Automation.CommandCompletion]::CompleteInput(
                <#ast#>                $ast,
                <#tokens#>                $tokens,
                <#positionOfCursor#>                $positionOfCursor,
                <#options#>                $options)
        }

        if ($results.CompletionMatches.Count -eq 0) {
            # Built-in didn't succeed, try our own completions here.
            if ($psCmdlet.ParameterSetName -eq 'ScriptInputSet') {
                $ast = [System.Management.Automation.Language.Parser]::ParseInput($inputScript, [ref]$tokens, [ref]$null)
            } else {
                $cursorColumn = $positionOfCursor.Offset
            }

            # workaround PowerShell bug that case it to not invoking native completers for - or --
            # making it hard to complete options for many commands
            $nativeCommandResults = TryNativeCommandOptionCompletion -ast $ast -offset $cursorColumn
            if ($null -ne $nativeCommandResults) {
                $results.ReplacementIndex = $nativeCommandResults.ReplacementIndex
                $results.ReplacementLength = $nativeCommandResults.ReplacementLength
                if ($results.CompletionMatches.IsReadOnly) {
                    # Workaround where PowerShell returns a readonly collection that we need to add to.
                    $collection = new-object System.Collections.ObjectModel.Collection[System.Management.Automation.CompletionResult]
                    $results.GetType().GetProperty('CompletionMatches').SetValue($results, $collection)
                }
                $nativeCommandResults.Results | ForEach-Object {
                    $results.CompletionMatches.Add($_)
                }
            }

            $attributeResults = TryAttributeArgumentCompletion $ast $cursorColumn
            if ($null -ne $attributeResults) {
                $results.ReplacementIndex = $attributeResults.ReplacementIndex
                $results.ReplacementLength = $attributeResults.ReplacementLength
                if ($results.CompletionMatches.IsReadOnly) {
                    # Workaround where PowerShell returns a readonly collection that we need to add to.
                    $collection = new-object System.Collections.ObjectModel.Collection[System.Management.Automation.CompletionResult]
                    $results.GetType().GetProperty('CompletionMatches').SetValue($results, $collection)
                }
                $attributeResults.Results | ForEach-Object {
                    $results.CompletionMatches.Add($_)
                }
            }
        }

        if ($options.ExcludeHiddenFiles) {
            foreach ($result in @($results.CompletionMatches)) {
                if ($result.ResultType -eq [System.Management.Automation.CompletionResultType]::ProviderItem -or
                    $result.ResultType -eq [System.Management.Automation.CompletionResultType]::ProviderContainer) {
                    try {
                        $item = Get-Item -LiteralPath $result.CompletionText -ErrorAction Stop
                    } catch {
                        # If Get-Item w/o -Force fails, it is probably hidden, so exclude the result
                        $null = $results.CompletionMatches.Remove($result)
                    }
                }
            }
        }
        if ($options.AppendBackslash -and
            $results.CompletionMatches.ResultType -contains [System.Management.Automation.CompletionResultType]::ProviderContainer) {
            foreach ($result in @($results.CompletionMatches)) {
                if ($result.ResultType -eq [System.Management.Automation.CompletionResultType]::ProviderContainer) {
                    $completionText = $result.CompletionText
                    $lastChar = $completionText[-1]
                    $lastIsQuote = ($lastChar -eq '"' -or $lastChar -eq "'")
                    if ($lastIsQuote) {
                        $lastChar = $completionText[-2]
                    }

                    if ($lastChar -ne '\') {
                        $null = $results.CompletionMatches.Remove($result)

                        if ($lastIsQuote) {
                            $completionText =
                            $completionText.Substring(0, $completionText.Length - 1) +
                            '\' + $completionText[-1]
                        } else {
                            $completionText = $completionText + '\'
                        }

                        $updatedResult = New-Object System.Management.Automation.CompletionResult `
                        ($completionText, $result.ListItemText, $result.ResultType, $result.ToolTip)
                        $results.CompletionMatches.Add($updatedResult)
                    }
                }
            }
        }

        if ($results.CompletionMatches.Count -eq 0) {
            # No results, if this module has overridden another TabExpansion2 function, call it
            # but only if it's not the built-in function (which we assume if function isn't
            # defined in a file.
            if ($oldTabExpansion2 -ne $null -and $oldTabExpansion2.File -ne $null) {
                return (& $oldTabExpansion2 @PSBoundParameters)
            }
        }

        return $results
    }


    #############################################################################
    #
    # Main
    #

    Add-Type @"
using System;
using System.Management.Automation;

public class NativeCommandTreeNode
{
    private NativeCommandTreeNode(NativeCommandTreeNode[] subCommands)
    {
        SubCommands = subCommands;
    }

    public NativeCommandTreeNode(string command, NativeCommandTreeNode[] subCommands)
        : this(command, null, subCommands)
    {
    }

    public NativeCommandTreeNode(string command, string tooltip, NativeCommandTreeNode[] subCommands)
        : this(subCommands)
    {
        this.Command = command;
        this.Tooltip = tooltip;
    }

    public NativeCommandTreeNode(string command, string tooltip, bool argument)
        : this(null)
    {
        this.Command = command;
        this.Tooltip = tooltip;
        this.Argument = true;
    }

    public NativeCommandTreeNode(ScriptBlock completionGenerator, NativeCommandTreeNode[] subCommands)
        : this(subCommands)
    {
        this.CompletionGenerator = completionGenerator;
    }

    public string Command { get; private set; }
    public string Tooltip { get; private set; }
    public bool Argument { get; private set; }
    public ScriptBlock CompletionGenerator { get; private set; }
    public NativeCommandTreeNode[] SubCommands { get; private set; }
}
"@

    # Custom completions are saved in this hashtable
    $tabExpansionOptions = @{
        CustomArgumentCompleters = @{ }
        NativeArgumentCompleters = @{ }
    }
    # Descriptions for the above completions saved in this hashtable
    $tabExpansionDescriptions = @{ }
    # And private data for the above completions cached in this hashtable
    $completionPrivateData = @{ }
}
# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDIDOeb9upxsdZ4
# 92Jf58BK8qmdSpdw/k+CiGDpc8KEyqCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAPlmmAMolnaNXMOsav7rN60uF9
# YuPoOoZv3uh8NfLK0zANBgkqhkiG9w0BAQEFAASCAQBAyU1kaL6ulgeE6Iy2To0C
# mkzbDlWepBIUgjslBVmKq3LNCjr2C+7EbwuwRV/88Cq3dFSjGA7ZwZjAPU4bQOKg
# IZTUM2HrWa8ewxosamQ6FZ61AHXaI2dM+lSJdEV1iRJdEQYWp4PdZgZ0EawCHOGg
# jels68T2trn8bWYOZObwl+O32Xx3yO7wrGLgGhEyIQr4o8zyb8uWujv2YrMJN4SR
# Hita5+Yf4P5RDYATkH27QUbcpoD7V2YS/0cXJVsSjsA2G40sszDTfoLIH4yNAtb+
# CgGSnd1zjdfAiArF2S1y0FVU2RwJy+m/x38ELWF7WtncXH3MrJbgQMuJ0y+auR2i
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIyMTAyMjIwMzgzMlowLwYJKoZIhvcNAQkEMSIE
# IH3vIHYKq0wZVji14mfEUmuvLUBPFCqsCr1AQkq1iYvqMA0GCSqGSIb3DQEBAQUA
# BIICAJnmgfSD2B6LNzgcTFIb/oGS6Zk4Yit83eTIZbUfRf9jGYGc8eHvnpEx1VlA
# 1n4MqCA2p22d02fO9zujGuScoTxKD6MAwzLEwN5/BrwyiTfg3DWyZlMNxn5DML1S
# Ki2uSnNborWA044xULhxQiAgJCbQ5duK5dVBIK0hcKfZhbEeqFsu+tASP9E4ITos
# UHJw9eym43+6sA+o+gvv3GKAyyYEAu+zobwiTNTDEaahZfHrRobueMiZKqaIqOoc
# yv9kNLlZEu+ILbJk1U4fKaz7vvLv4XbCWmXh/d01dyZNsOnVKNxy3HJLM+dolX82
# 4USi9x266Dl2r6ef0mvNsAhzGCDiIVXnA1iCM27kEv0kj2wHHRWDKX9juVuDkt1G
# sIwizgl3IdH6e1U4V2D10980ou6iiR7UZzGoNdCVUAxtppOVMp8T4JYWG2RDW6Us
# 7/KYgZnF116jQh3d9enm9dRGmI0RFgyeJ3fU2qxpwmCIdIZjW09/G5wkAjXBOQEi
# ow/JgwbHJMNnNiGVQQNPGGx6K/+tickltOT44Fkv+YGLY1n7U36w3Ag7PAQKkMG6
# GRT0/id4p9jIxJJxpptaq+yrtxRetnCWQpMjeoSn2bVTM9mbWjap/ZYA5A5WSY1o
# HkRIHtks+eYrg8SjGhPrtR4Mao/jGdFUYKZNiIaLwV/tl4fl
# SIG # End signature block
