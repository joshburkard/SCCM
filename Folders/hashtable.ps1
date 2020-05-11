Function Get-FolderPath{
    param(
        [Parameter(Mandatory=$true)]$containerNode,
        [Parameter(Mandatory=$true)]$folders
    )
    $folderPath = '/'
    if($containerNode -eq $null){
        return $folderPath
    }

    if($folders.ContainsKey($containerNode.ParentContainerNodeID)){
        $folderPath = "$(Get-FolderPath `
				-containerNode $folders[$containerNode.ParentContainerNodeID] `
				-folders $folders)$($containerNode.Name)/"
        return $folderPath
    }
    return "$folderPath$($containerNode.Name)/"
}

$server = "nm-cm12"
$siteCode = "ps1"
$collections = Get-WmiObject -ComputerName $server -Namespace root\sms\site_$siteCode `
				-Query "select * from SMS_Collection where CollectionType='2'"
$folders = Get-WmiObject -ComputerName $server -Namespace root\sms\site_$siteCode `
				-Query "select * from SMS_ObjectContainerNode where ObjectType='5000'"
$containerItems = Get-WmiObject -ComputerName $server -Namespace root\sms\site_$siteCode `
				-Query "select * from SMS_ObjectContainerItem where ObjectType='5000'"

$dictContainerItems = @{}
foreach($containerItem in $containerItems){
    $dictContainerItems.Add($containerItem.InstanceKey, $containerItem)
}

$dictFolders = @{}
foreach($folder in $folders){
    $dictFolders.Add($folder.ContainerNodeID, $folder)
}

foreach($collection in $collections){
    $node = $null
    $item = $null

    if($dictContainerItems.ContainsKey($collection.CollectionID)){
        $item = $dictContainerItems[$collection.CollectionID]
    }

    if($item -ne $null -and $dictFolders.ContainsKey($item.ContainerNodeID)){
        $node = $dictFolders[$item.ContainerNodeID]
    }

    if($node -ne $null){
        $folder = Get-FolderPath -containerNode $node -folders $dictFolders `
					-ErrorAction SilentlyContinue
    }
    else{
        $folder = '/'
    }
    Write-Output "$folder$($collection.Name)"
}
