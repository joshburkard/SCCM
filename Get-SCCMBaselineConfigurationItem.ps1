function Get-SCCMBaselineConfigurationItem {
    <#
        .SYNOPSIS
            returns the assigned configuration items for a specific baseline

        .DESCRIPTION
            returns the assigned configuration items for a specific baseline

        .PARAMETER SiteServer
            NETBIOS or FQDN address for the configurations manager 2012 site server

        .PARAMETER SiteCode
            Site Code for the configurations manager 2012 site server

        .PARAMETER BaselineName
            defines the name of the baseline

        .EXAMPLE
            Get-SCCMBaselineConfigurationItem -SiteServer $SiteServer -SiteCode $SiteCode -BaselineName $BaselineName

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
        [Parameter(Mandatory=$true)]
        [string]$BaselineName
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    try {
        $wmiquery = "SELECT * FROM SMS_ConfigurationBaselineInfo WHERE LocalizedDisplayName = '$( $BaselineName )'"
        $Baseline = Get-WmiObject -Namespace "root\SMS\site_${SiteCode}" -ComputerName $SiteServer -Query $wmiquery

        $wmiquery = "SELECT * FROM SMS_ConfigurationItem WHERE IsLatest=1 AND ModelName = '$( $Baseline.ModelName )'"
        $ci = Get-WmiObject -Namespace "root\SMS\site_${SiteCode}" -ComputerName $SiteServer -Query $wmiquery

        $SDM = $ci.GetSDMDefinition().SDMDefinition

        if ( [boolean]( ( ( [xml]$SDM ).model.instances.document | Where-Object { $_.documentType -eq 0 } ).data.DesiredConfigurationDigest.Baseline.OperatingSystems ) ) {
            $ConnectedCIs = ( ( [xml]$SDM ).model.instances.document | Where-Object { $_.documentType -eq 0 } ).data.DesiredConfigurationDigest.Baseline.OperatingSystems.OperatingSystemReference
            $CIs = @()
            $ConnectedCIs | ForEach-Object {
                $wmiquery = "SELECT * FROM SMS_ConfigurationItemLatest WHERE ModelName Like '%$( $_.LogicalName )'"
                $Item = Get-WmiObject -Namespace "root\SMS\site_${SiteCode}" -ComputerName $SiteServer -Query $wmiquery
                $LatestVersion = $Item.CIVersion
                if ( $_.Version ) {
                    $wmiquery = "SELECT * FROM SMS_ConfigurationItem WHERE ModelName Like '%$( $_.LogicalName )' AND CIVersion=$( $_.Version )"
                    $Item = Get-WmiObject -Namespace "root\SMS\site_${SiteCode}" -ComputerName $SiteServer -Query $wmiquery
                    $ConfiguredVersion = $_.Version
                }
                else {
                    $ConfiguredVersion = 'Latest'
                }

                $CIs += [PSCustomObject]@{
                    CI_ID                = $Item.CI_ID
                    ConfiguredVersion    = $ConfiguredVersion
                    LatestVersion        = $LatestVersion
                    LocalizedDisplayName = $Item.LocalizedDisplayName
                    LocalizedDescription = $Item.LocalizedDescription
                }
            }
            $ret = $CIs
        }
        else {
            $ret = $null
        }
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
    finally {

    }
    return $ret
}