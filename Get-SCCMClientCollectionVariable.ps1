function Get-SCCMClientCollectionVariables {
    <#
        .SYNOPSIS
            This function gets the Device and Collection variables from the local SCCM client

        .DESCRIPTION
            This function gets the Device and Collection variables from the local SCCM client

            to run this function, it must be started in the context of NT AUTHORITY SYSTEM
        
        .PARMETER Name
            defines the Name of the Variable to query

        .EXAMPLE
            Get-SCCMClientCollectionVariables

        .EXAMPLE
            Get-SCCMClientCollectionVariables -Name 'Stage'

    #>
    [CmdletBinding()]
    Param (
        [string]$Name
    )
    Add-Type -AssemblyName System.Security

    <#
    Function Convert-ByteArrayToHex {
        [cmdletbinding()]
        param(
            [parameter(Mandatory=$true)]
            [Byte[]]
            $Bytes
        )
        $HexString = [System.Text.StringBuilder]::new($Bytes.Length * 2)
        ForEach($byte in $Bytes){
            $HexString.AppendFormat("{0:x2}", $byte) | Out-Null
        }
        $HexString.ToString()
    }
    #>

    Function Convert-HexToByteArray {
        [cmdletbinding()]
        param(
            [parameter(Mandatory=$true)]
            [String]
            $HexString
        )
        $Bytes = [byte[]]::new($HexString.Length / 2 - 4)
        for ($i = 0; $i -lt ( $HexString.Length / 2 - 4 ); $i++) {
            $Bytes[$i] = [convert]::ToByte( $HexString.Substring( ( ( $i + 4 ) *2 ), 2), 16 )
        }
        return $Bytes
    }

    Function Unprotect-SCCMValue {
        <#
            .SYNOPSIS
                this function decrypt the value, which was encrypted by the SCCM client
            
            .DESCRIPTION
                this function decrypt the value, which was encrypted by the SCCM client

                this function must be run in the context of NT AUTHORITY SYSTEM
            
            .PARAMETER value
                the string value, which is encrypted

            .EXAMPLE
                $value = '<PolicySecret Version="1"><![CDATA[2601000001000000D08C9DDF0115D1118C7A00C04FC297EB01000000D5D3C53250BE0E4B81265FB6A36337460000000002000000000010660000000100002000000050ADD631B3FFCC68F9D8C3C9B899009DF0BBE81A11EFD4AE8CC6AF8935B2BC7C000000000E8000000002000020000000C582A0D57FA0A3016C81F332802E0464F8CDC813B1070FF3CB96BB7E329ED0DF50000000FD8D2DCED187084A885B778144C46EA369212E470AF989598093232D768ADFE0B4FB4A20E2FD91152BD72FB500B46D1607A9ACD45D669E1FE18145CAB037C8CB1122FAB513C491E50F29FB87EA2DE75D400000008F4F518FB5489B8092B9E41085C9B18C60BB56E9C845EFCC7635B6B31FEF5E073D88736D9B6DFEB4A008C6FB9133FA8EBEFF1A26BB7B3B66F8AD62E72A60C5CE]]></PolicySecret>'

                Unprotect-SCCMValue -value $value
        #>
        Param (
            $Value
        )    
        [xml]$xml = $Value
        $EncryptedValue = $xml.DocumentElement.InnerText

        $EncryptedData = Convert-HexToByteArray -HexString $EncryptedValue
    
        try {
            $UnprotectedData = [System.Security.Cryptography.ProtectedData]::Unprotect($EncryptedData, [byte[]]$null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        }
        catch {
            $UnprotectedData = $null
            $Value
        }
        if ( [boolean]$UnprotectedData ) {
            $i = 0
            # use only every second byte
            $Bytes = $UnprotectedData | Where-Object { $i % 2 -eq 0; $i++ }
            # dont use the last byte
            $Bytes = @( $Bytes )[0 .. ( @( $Bytes ).Count - 2 ) ]
            $result = [System.Text.Encoding]::ASCII.GetString( $Bytes )
            return $result
        }
        else {
            return $Value
        }
    }

    if ( $env:USERNAME -ne "$( $env:COMPUTERNAME )$('$')" ) {
        throw "this function must be run in context of NT AUTHORITY SYSTEM"
    }

    $variables = Get-WmiObject -Namespace "ROOT\ccm\Policy\Machine\ActualConfig" -Class "CCM_CollectionVariable"
    if ( [boolean]$Name ) {
        $variables = $variables | Where-Object { $_.Name -eq $Name }
    }
    $result = $variables | Select-Object Name, @{ Name="Value"; Expression={ Unprotect-SCCMValue -Value $_.value } }
    return ( $result | Sort-Object Name )
}
