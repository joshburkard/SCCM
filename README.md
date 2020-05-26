# SCCM

This repository contains some functions, i use regularly

## Invoke-SCCMScript

this function allows to invoke a CMScript and pass parameters to it.

(the builtin cmdlet Invoke-CMScript doesn't allow to pass parameters)

```PowerShell
# parameters to send to the script
$InputParameters = @{
    param1 = 'Test 1'
    param2 = 'Test 2'
}

$Params = @{
    SiteServer        = 'server.fqdn.net'
    SiteCode          = 'P00'
    ScriptName        = 'Test Script'
    TargetResourceIDs = '11111111'
    InputParameters   = $InputParameters
}
$ScriptResult = Invoke-SCCMScript @Params
```

## Get-SCCMScriptExecutionStatus

this function allows to read the status of a CMScript and returns the output

```PowerShell
$OperationID = $ScriptResult.OperationID
$Params = @{
    SiteServer        = 'server.fqdn.net'
    SiteCode          = 'P00'
    OperationID       = $OperationID
}
Get-SCCMScriptExecutionStatus @params

```

## Get-SCCMBaselineConfigurationItem

returns the assigned configuration items for a specific baseline

```PowerShell
Get-SCCMBaselineConfigurationItem -SiteServer $SiteServer -SiteCode $SiteCode -BaselineName $BaselineName
```

## Set-SCCMBaselineConfigurationItem

set the assigned configuration items on a baseline to a specific version

```PowerShell
# sets the assigned configuration item to a specific version
Set-SCCMBaselineConfigurationItem -SiteServer $SiteServer -SiteCode $SiteCode -BaselineName $BaselineName -ConfigurationItemName $ConfigurationItemName -Version 1

# sets the assigned configuration item to 'Latest'
Set-SCCMBaselineConfigurationItem -SiteServer $SiteServer -SiteCode $SiteCode -BaselineName $BaselineName -ConfigurationItemName $ConfigurationItemName -Latests
```

## Get-ClientCollectionVariables

this function get all collection variables from the local SCCM client.

to use this function, it must be executed in the context of NT AUTHORITY SYSTEM.

```PowerShell
Get-ClientCollectionVariables
```