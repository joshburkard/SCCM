function Connect-SCCM {
    <#
        .SYNOPSIS
            connects to an SCCM Site

        .DESCRIPTION
            connects to an SCCM Site

        .PARAMETER SiteServer
            this parameter will be used to define the Site Server

            this string parameter is mandatory

        .PARAMETER SiteCode
            this parameter will be used to define the Site Code

            this string parameter is mandatory

        .EXAMPLE
            connect-SCCM SiteServer 'server.fqdn.net' -SiteCode 'P00'

        .NOTES
            File-Name:  Invoke-SCCMScript.ps1
            Author:     Josh Burkard - josh@burkard.it
            Version:    0.1.00001

            Changelog:
                0.1.00001, 2019-07-29, Josh Burkard, initial creation

            Links:
                https://github.com/joshburkard/SCCM

    #>
    [CmdletBinding()]
    Param (
        [string]$SiteServer ,
        [string]$SiteCode
    )

    # Import the ConfigurationManager.psd1 module
    if ( $null -eq ( Get-Module ConfigurationManager ) ) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Scope Global
        Write-Verbose "module 'ConfigurationManager' loaded"
    }

    # Connect to the site's drive if it is not already present
    if ( ! ( Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue ) ) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -Scope Global | Out-Null
        Write-Verbose "created PSDrive '$( $SiteCode )' on server '$( $SiteServer )'"
    }

    # Set the current location to be the site code.
    if ( $( Get-Location ).Path -ne "$( $SiteCode ):\") {
        Set-Location -Path "$( $SiteCode ):\"
        Write-Verbose "connected to SCCM site '$( $SiteCode )'"
    }
}