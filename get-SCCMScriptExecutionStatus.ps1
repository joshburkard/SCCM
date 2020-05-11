function Get-SCCMScriptExecutionStatus {
    <#
        .SYNOPSIS
            returns the current status of a SCCM Script

        .DESCRIPTION
            returns the current status of a SCCM Script

        .PARAMETER SiteServer
            this parameter will be used to define the Site Server

            this string parameter is mandatory

        .PARAMETER SiteCode
            this parameter will be used to define the Site Code

            this string parameter is mandatory

        .PARAMETER OperationID
            defines the OperationID

        .EXAMPLE
            Get-SCCMScriptExecutionStatus -SiteServer $SiteServer -SiteCode $SiteCode -OperationID $OperationID

        .NOTES
            File-Name:  Get-SCCMScriptExecutionStatus.ps1
            Author:     Josh Burkard - josh@burkard.it
            Version:    0.1.00005

            Changelog:
                0.1.00001, 2019-07-29, Josua Burkard, initial creation
                0.1.00002, 2019-08-26, Josua Burkard, general script changes
                0.1.00003, 2019-08-29, Josua Burkard, working version
                0.1.00004, 2019-08-29, Josua Burkard, result was cutted after 4000 chars
                0.1.00005, 2020-05-11, Josh Burkard, modifyining public version

            Links:


    #>
    [OutputType([System.Object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteServer,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteCode,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OperationID
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    try {
        [string]$Namespace = "ROOT\SMS\site_$( $SiteCode )"

        $WMIQuery = "Select * from SMS_ScriptsExecutionTask where ClientOperationId=$( $OperationID )"
        $TaskStatus = Get-WmiObject -Namespace $Namespace -ComputerName $SiteServer -Query $WMIQuery

        if ( [string]::IsNullOrEmpty( $TaskStatus ) ) {
            $ret = [PSCustomObject]@{
                OperationID = $OperationID
                ScriptName  = 'Operation not found'
                Results     = $null
                Status      = 'error'
                TotalClients         = $null
                CompletedClients     = $null
                FailedClients        = $null
                OfflineClients       = $null
                NotApplicableClients = $null
                UnknownClients       = $null
                LastUpdateTime       = $null
            }
        }
        else {
            if ( $TaskStatus.CompletedClients -gt 0 ) {
                $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionStatus where ClientOperationId=$( $OperationID )"
                $ClientStatus = Get-WmiObject -Namespace $Namespace -ComputerName $SiteServer -Query $WMIQuery
                $ClientStatus.get
                $ClientStatus.Get()
                $Results = @()
                if ( $TaskStatus.CompletedClients -eq $TaskStatus.TotalClients ) {
                    $Status = "all clients completed"
                }
                else {
                    $Status = "some clients completed"
                }
                foreach ( $c in $ClientStatus ) {
                    $Results += [PSCustomObject]@{
                        ResourceID           = $c.ResourceId
                        DeviceName           = $c.DeviceName
                        ScriptExecutionState = $c.ScriptExecutionState
                        ScriptExitCode       = $c.ScriptExitCode
                        ScriptOutput         = $c.ScriptOutput
                    }
                }
                $ret = [PSCustomObject]@{
                    OperationID          = $OperationID
                    ScriptName           = $TaskStatus.ScriptName
                    Results              = $Results
                    Status               = $Status
                    TotalClients         = $TaskStatus.TotalClients
                    CompletedClients     = $TaskStatus.CompletedClients
                    FailedClients        = $TaskStatus.FailedClients
                    OfflineClients       = $TaskStatus.OfflineClients
                    NotApplicableClients = $TaskStatus.NotApplicableClients
                    UnknownClients       = $TaskStatus.UnknownClients
                    LastUpdateTime       = $TaskStatus.LastUpdateTime
                }
            }
            else {
                $ret = [PSCustomObject]@{
                    OperationID          = $OperationID
                    ScriptName           = $TaskStatus.ScriptName
                    Results              = $null
                    Status               = 'no client completed'
                    TotalClients         = $TaskStatus.TotalClients
                    CompletedClients     = $TaskStatus.CompletedClients
                    FailedClients        = $TaskStatus.FailedClients
                    OfflineClients       = $TaskStatus.OfflineClients
                    NotApplicableClients = $TaskStatus.NotApplicableClients
                    UnknownClients       = $TaskStatus.UnknownClients
                    LastUpdateTime       = $TaskStatus.LastUpdateTime
                }
            }
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
    return $ret
}
