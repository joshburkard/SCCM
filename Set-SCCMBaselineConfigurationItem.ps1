function Set-SCCMBaselineConfigurationItem {
    <#
        .SYNOPSIS
            set the assigned configuration items on a baseline to a specific version

        .DESCRIPTION
            set the assigned configuration items on a baseline to a specific version

        .PARAMETER  SiteServer
            NETBIOS or FQDN address for the configurations manager 2012 site server

        .PARAMETER SiteCode
            Site Code for the configurations manager 2012 site server

        .PARAMETER BaselineName
            defines the name of the baseline

        .PARAMETER ConfigurationItemName
            defines the name of the configuration item

        .PARAMETER Version
            defines a specific version

            if the version is set to the highest version number and the configuration item will be updated, the baseline will still use the
            specified version and not the latest version

        .PARAMETER Latest
            defines the latest version

            if latests is defined and the configuration item will be updated, then the baseline will automatically use the new latest version

        .EXAMPLE
            Set-SCCMBaselineConfigurationItem -SiteServer $SiteServer -SiteCode $SiteCode -BaselineName $BaselineName -ConfigurationItemName $ConfigurationItemName -Version 1

        .EXAMPLE
            Set-SCCMBaselineConfigurationItem -SiteServer $SiteServer -SiteCode $SiteCode -BaselineName $BaselineName -ConfigurationItemName $ConfigurationItemName -Latests

        .NOTES
            File-Name:  Invoke-SCCMScript.ps1
            Author:     Josh Burkard - josh@burkard.it
            Version:    0.1.00002

            Changelog:
                0.1.00001, 2020-03-02, Josh Burkard, initial creation
                0.1.00002, 2020-05-11, Josh Burkard, modifyining public version

            Links:
                https://github.com/joshburkard/SCCM

    #>
    [OutputType([PSCustomObject[]])]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$SiteServer
        ,
        [Parameter(Mandatory=$true)]
        [string]$SiteCode
        ,
        [Alias("BLName")]
        [Parameter(Mandatory=$true)]
        [string]$BaselineName
        ,
        [Alias("CIName")]
        [Parameter(Mandatory=$true)]
        [string]$ConfigurationItemName
        ,
        [Parameter(ParameterSetName="Version",Mandatory=$true)]
        [int]$Version
        ,
        [Parameter(ParameterSetName="Latest",Mandatory=$true)]
        [switch]$Latests
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    try {
        $tempFilePath = Join-Path -Path $env:TEMP -ChildPath "DesiredConfigurationDigest.xml"

        $wmiquery = "SELECT * FROM SMS_ConfigurationItem WHERE LocalizedDisplayName = '$( $ConfigurationItemName )'"
        $ci = Get-WmiObject -Namespace "root\SMS\site_${SiteCode}" -ComputerName $SiteServer -Query $wmiquery
        $ModelName = $ci.ModelName | Select-Object -Unique
        $Versions = $ci.SDMPackageVersion
        if ( $Version ) {
            if ( $Version -notin $Versions ) {
                throw "version $( $Version ) not available in @( $( $Versions -join ', ' ) )"
            }
        }
        $AuthoringScopeId = @( $ModelName -split '/' )[0]
        $LogicalName = @( $ModelName -split '/' )[1]

        [xml]$CMBaselineXMLDefinition = Get-CMBaselineXMLDefinition -Name $BaselineName
        if ( [string]::IsNullOrEmpty( $CMBaselineXMLDefinition ) ) {
            throw "couldn't find baseline '$( $BaselineName )'"
        }
        $OSReferences = $CMBaselineXMLDefinition.DesiredConfigurationDigest.Baseline.OperatingSystems.OperatingSystemReference
        $OSReference = $OSReferences | Where-Object { $_.AuthoringScopeId -eq $AuthoringScopeId -and $_.LogicalName -eq $LogicalName }
        if ( [string]::IsNullOrEmpty( $OSReference ) ) {
            $CIID = ( Get-CMConfigurationItem -Name $ConfigurationItemName -Fast ).CI_ID
            Set-CMBaseline -Name $BaselineName -AddOSConfigurationItem $CIID

            # get OS Reference again
            [xml]$CMBaselineXMLDefinition = Get-CMBaselineXMLDefinition -Name $BaselineName
            $OSReferences = $CMBaselineXMLDefinition.DesiredConfigurationDigest.Baseline.OperatingSystems.OperatingSystemReference
            $OSReference = $OSReferences | Where-Object { $_.AuthoringScopeId -eq $AuthoringScopeId -and $_.LogicalName -eq $LogicalName }
        }
        if ( [string]::IsNullOrEmpty( $OSReference ) ) {
            throw "couldn't add configuration item to base line"
        }
        if ( $Latest ) {
            if ( $OSReference.HasAttribute( 'Version' ) ) {
                $OSReference.RemoveAttribute('Version')
            }
        }
        else {
            $OSReference.SetAttribute('Version', $Version )
        }

        $CMBaselineXMLDefinition.OuterXml | Out-File -FilePath $tempFilePath

        Set-CMBaseline -Name $BaselineName -DesiredConfigurationDigestPath $tempFilePath

        Remove-Item -Path $tempFilePath -Force -Confirm:$false
    }
    catch {
        $ret = [PSCustomObject]@{
            Succeeded  = $false
            Function   = $function
            Activity   = $($_.CategoryInfo).Activity
            Message    = $($_.Exception.Message)
            Category   = $($_.CategoryInfo).Category
            Exception  = $($_.Exception.GetType().FullName)
            TargetName = $($_.CategoryInfo).TargetName
        }
        #don't forget to clear the error-object
        $error.Clear()
    }
    return $ret
}