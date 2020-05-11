function Invoke-SCCMScript {
    <#
        .SYNOPSIS
            Runs a SCCM Script with input parameters

        .DESCRIPTION
            Runs a SCCM Script.

            in addition to the origin cmdlet Invoke-CMScript, it allows to pass input parameters to the script

        .PARAMETER SiteServer
            this parameter will be used to define the Site Server

            this string parameter is mandatory

        .PARAMETER SiteCode
            this parameter will be used to define the Site Code

            this string parameter is mandatory

        .PARAMETER ScriptName
            the name of the script to be invoked

            this string parameter is mandatory

        .PARAMETER InputParameter
            any parameters, which should be passed to the script

            if the script has some default values, they will be used, if not defined

            this parameter is not mandatory

        .PARAMETER TargetCollectionID
            the id of the target collection

            the parameter TargetCollectionID or TargetResourceIDs is mandatory, but not both

        .PARAMETER TargetResourceIDs
            the id of the target resources

            the parameter TargetCollectionID or TargetResourceIDs is mandatory, but not both

        .EXAMPLE
            $InputParameters = @{
                fileName = 'C:\Temp\test.csv'
                To = 'josh@burkard.it'
            }

            $Params = @{
                SiteServer = 'server.fqdn.net'
                SiteCode  = 'P00'
                ScriptName = 'Test Script'
                TargetResourceIDs = '11111111'
                InputParameters = $InputParameters
            }
            Invoke-SCCMScript @Params

        .NOTES
            File-Name:  Invoke-SCCMScript.ps1
            Author:     Josh Burkard - josh@burkard.it
            Version:    0.1.00005

            Changelog:
                0.1.00001, 2019-07-29, Josh Burkard, initial creation
                0.1.00002, 2019-07-30, Josh Burkard, changed Parameter validation
                0.1.00003, 2019-08-09, Josh Burkard, added validation of script ApprovalState
                0.1.00004, 2020-03-02, Josh Burkard, using default values, when a CMScript parameter isHidden
                0.1.00005, 2020-05-11, Josh Burkard, modifyining public version

            Links:
                https://github.com/joshburkard/SCCM

    #>
    [OutputType([System.Management.ManagementBaseObject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteServer
        ,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteCode
        ,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName
        ,
        [Parameter(Mandatory=$false)]
        [Array]$InputParameters = @()
        ,
        [Parameter(Mandatory=$false)]
        [string]$TargetCollectionID = ""
        ,
        [Parameter(Mandatory=$false)]
        [Array]$TargetResourceIDs = @()
    )
    [string]$Namespace = "ROOT\SMS\site_$( $SiteCode )"

    # if something goes wrong, we want to stop!
    $ErrorActionPreference = "Stop"

    # We can not run on all members of a collection AND selected resources
    if ( -not ([string]::IsNullOrEmpty( $TargetCollectionID ) ) -and ( $TargetResourceIDs -gt 0) ) {
        throw "Use either TargetCollectionID or TargetResourceIDs, not both!"
    }
    if ( ( [string]::IsNullOrEmpty( $TargetCollectionID ) ) -and ( $TargetResourceIDs -lt 1) ) {
        throw "We need some resources (devices) to run the script!"
    }

    # Get the script
    $Script = [wmi](Get-WmiObject -class SMS_Scripts -Namespace $Namespace -ComputerName $SiteServer -Filter "ScriptName = '$ScriptName'").__PATH

    if ( -not $Script ) {
        throw "Could not find script with name '$ScriptName'"
    }
    if ( $Script.ApprovalState -ne 3 ) {
        throw "script couldn't be invoked, cause it isn't approved"
    }
    # Parse the parameter definition
    $Parameters = [xml]([string]::new([Convert]::FromBase64String( $Script.ParamsDefinition ) ) )

    $Parameters.ScriptParameters.ChildNodes | ForEach-Object {
        if ( ( $_.IsRequired ) -and ( $_.IsHidden -ne $true ) -and ( $_.Name -notin $InputParameters.Keys ) ) {
            throw "Script '$( $ScriptName )' has required parameters '$( $_.Name )' but no parameters was passed."
        }
    }

    # create GUID used for parametergroup
    $ParameterGroupGUID = $(New-Guid)

    if ($InputParameters.Count -le 0) {
        # If no ScriptParameters: <ScriptParameters></ScriptParameters> and an empty hash
        $ParametersXML = "<ScriptParameters></ScriptParameters>"
        $ParametersHash = ""
    }
    else {
        $InnerParametersXML = ''
        foreach ( $ChildNode in $Parameters.ScriptParameters.ChildNodes ) {
            $ParamName = $ChildNode.Name
            if ( $ChildNode.IsHidden -eq 'true' ) {
                $Value = $ChildNode.DefaultValue
            }
            else {
                if ( $ParamName -in $InputParameters.Keys ) {
                    $Value = $InputParameters."$( $ParamName )"
                }
                else {
                    $Value = ''
                }
            }
            $InnerParametersXML = "$( $InnerParametersXML )<ScriptParameter ParameterGroupGuid=`"$( $ParameterGroupGUID )`" ParameterGroupName=`"PG_$( $ParameterGroupGUID )`" ParameterName=`"$( $ParamName )`" ParameterType=`"$( $ChildNode.Type )`" ParameterValue=`"$( $Value )`"/>"
        }
        $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

        $SHA256 = [System.Security.Cryptography.SHA256Cng]::new()
        $Bytes = ($SHA256.ComputeHash(([System.Text.Encoding]::Unicode).GetBytes($ParametersXML)))
        $ParametersHash = ($Bytes | ForEach-Object ToString X2) -join ''
    }

    $RunScriptXMLDefinition = "<ScriptContent ScriptGuid='{0}'><ScriptVersion>{1}</ScriptVersion><ScriptType>{2}</ScriptType><ScriptHash ScriptHashAlg='SHA256'>{3}</ScriptHash>{4}<ParameterGroupHash ParameterHashAlg='SHA256'>{5}</ParameterGroupHash></ScriptContent>"
    $RunScriptXML = $RunScriptXMLDefinition -f $Script.ScriptGuid,$Script.ScriptVersion,$Script.ScriptType,$Script.ScriptHash,$ParametersXML,$ParametersHash

    # Get information about the class instead of fetching an instance
    # WMI holds the secret of what parameters that needs to be passed and the actual order in which they have to be passed
    $MC = [WmiClass]"\\$SiteServer\$($Namespace):SMS_ClientOperation"

    # Get the parameters of the WmiMethod
    $MethodName = 'InitiateClientOperationEx'
    $InParams = $MC.psbase.GetMethodParameters($MethodName)

    # Information about the script is passed as the parameter 'Param' as a BASE64 encoded string
    $InParams.Param = ([Convert]::ToBase64String(([System.Text.Encoding]::UTF8).GetBytes($RunScriptXML)))
    # ([System.Text.Encoding]::UTF8.GetString( [convert]::FromBase64String($InParams.Param  ) ) )

    # Hardcoded to 0 in certain DLLs
    $InParams.RandomizationWindow = "0"

    # If we are using a collection, set it. TargetCollectionID can be empty string: ""
    $InParams.TargetCollectionID = $TargetCollectionID

    # If we have a list of resources to run the script on, set it. TargetResourceIDs can be an empty array: @()
    # Criteria for a "valid" resource is IsClient=$true and IsBlocked=$false and IsObsolete=$false and ClientType=1
    $InParams.TargetResourceIDs = $TargetResourceIDs

    # Run Script is type 135
    $InParams.Type = "135"

    # Everything should be ready for processing, invoke the method!
    try {
        $Result = $MC.InvokeMethod($MethodName, $InParams, $null)
    }
    catch {
        $Result = [PSCustomObject]@{

        }
    }
    # The result contains the client operation id of the execution
    $Result
}
