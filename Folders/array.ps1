Function Get-FolderPath{
    param(
        [Parameter(Mandatory=$true)]$containerNode,
        [Parameter(Mandatory=$true)]$folders
    )
    $folderPath = '/'
    if($containerNode -eq $null){
        return $folderPath
    }
    foreach($folder in $folders){
        if($containerNode.ParentContainerNodeID -eq $folder.ContainerNodeID){
            $folderPath = "$(Get-FolderPath -containerNode $folder -folders $folders)$($containerNode.Name)/"
            return $folderPath
        }
    }
    return "$folderPath$($containerNode.Name)/"
}

$siteServer = "nm-cm12"
$siteCode = "ps1"
$collections = Get-WmiObject -ComputerName $siteServer -Namespace root\sms\site_$siteCode -Query "select * from SMS_Collection where CollectionType='2'"
$folders = Get-WmiObject -ComputerName $siteServer -Namespace root\sms\site_$siteCode -Query "select * from SMS_ObjectContainerNode where ObjectType='5000'"
$containerItems = Get-WmiObject -ComputerName $siteServer -Namespace root\sms\site_$siteCode -Query "select * from SMS_ObjectContainerItem where ObjectType='5000'"

foreach($collection in $collections){
    $node = $null
    $item = $null
    foreach($containerItem in $containerItems){
        if($containerItem.InstanceKey -eq $collection.CollectionID){
            $item = $containerItem
            break
        }
    }
    foreach($containerNode in $folders){
        if($item.ContainerNodeID -eq $containerNode.ContainerNodeID){
            $node = $containerNode
        }
    }
    if($node -ne $null){
        $folder = Get-FolderPath -containerNode $node -folders $folders -ErrorAction SilentlyContinue
    }
    else{
        $folder = '/'
    }
    Write-Output "$folder$($collection.Name)"
}
