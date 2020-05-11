[cmdletbinding()]
Param(
    $value
)
Write-Verbose "verbose-test"
$ExitCode = 1

Get-Variable

$oResult = New-Object -TypeName PSObject -Property ([Ordered]@{
    "ExitCode" = $Exitcode
    "StdOut"   = $script:Verbose
    "StdErr"   = $Errormessage
})
return $oResult