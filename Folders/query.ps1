Function Get-FolderPath{
    param(
        [Parameter(Mandatory=$true)][string]$collectionId,
        [Parameter(Mandatory=$true)][string]$siteServer,
        [Parameter(Mandatory=$true)][string]$siteCode
    )
    $folderPath = '/'
	$query = "select * from SMS_ObjectContainerItem where ObjectType='5000' `
				and InstanceKey='$collectionId'"
    $containerId = (Get-WmiObject -ErrorAction SilentlyContinue -ComputerName $siteServer `
					-Namespace root\sms\site_$siteCode -Query "$query").ContainerNodeID
    if($containerId -eq $null){
        return $folderPath
    }
	$query = "select * from SMS_ObjectContainerNode where `
				ContainerNodeID='$containerId'"
    $folder = (Get-WmiObject -ErrorAction SilentlyContinue -ComputerName $siteServer `
				-Namespace root\sms\site_$siteCode -Query "$query")
    while($folder -ne $null)
    {
        $folderPath += $folder.Name + '/'
		$query = "select * from SMS_ObjectContainerNode `
					where ContainerNodeID='$($folder.ParentContainerNodeID)'"
        $folder = (Get-WmiObject -ErrorAction SilentlyContinue `
		-ComputerName $siteServer -Namespace root\sms\site_$siteCode -Query "$query")
    }
    return $folderPath
}

$server = "nm-cm12"
$siteCode = "ps1"
$query = "select * from SMS_Collection where CollectionType='2'"
$collections = Get-WmiObject -ComputerName $server -Namespace root\sms\site_$siteCode `
				-Query "$query"

foreach($collection in $collections){
    $folder = Get-FolderPath -collectionId $collection.CollectionID -siteServer $server -siteCode $siteCode
    Write-Output "$folder$($collection.Name)"
}