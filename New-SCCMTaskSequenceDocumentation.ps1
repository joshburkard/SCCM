Import-Module -Name swisscom.scs.systemcenter.configmgr
$SiteServer = 'poap0cas-1.scmgmt.net'
$SiteCode = 'P00'
Connect-SCCM -SiteServer $SiteServer -SiteCode $SiteCode

function New-SCCMTaskSequenceDocumentation {
    Param (
        [string]$SiteCode = 'P00'
        ,
        [string]$SiteServer = 'poap0cas-1.scmgmt.net'
        ,
        [string]$TaskSequenceName = 'P00_All_TAS_WindowsUpdates'
        ,
        [string]$FilePath
    )
    Import-Module -Name PSHTML

    function Get-SCCMTSStructure {
        Param (
            $Item
            ,
            [int]$Level = 0
            ,
            [int]$OrderID = 0
            # ,
            # [string]$ParentID = ''
        )
        # $ChildItem = @( $Item.ChildNodes )[0]
        $results = @()
        # $ChildItem = @( $Item.ChildNodes | Where-Object { ( [boolean]$_.group ) -or ( [boolean]$_.step ) } )[0]
        $i = 0
        foreach ( $ChildItem in @( $Item.ChildNodes | Where-Object { $_.LocalName -in @( 'group', 'step' ) } ) ) {
            $i++
            $OrderID++
            <#
            if ( [boolean]$ParentID ) {
                $ID = "$( $ParentID )-$( $i.ToString().PadLeft(4,'0') )"
            }
            else {
                $ID = $i.ToString().PadLeft(4,'0')
            }
            #>
            if ( [boolean]$ChildItem.reference ) {
                $StepType = 'reference'
                $content = $null
            }
            elseif ( [boolean]$ChildItem.type ) {
                $StepType = 'step'
                # $content = $ChildItem.InnerXml
            }
            else {
                $StepType = 'group'
            }
            $content = $ChildItem.OuterXml
            <#
            elseif ( ( [boolean]$ChildItem.group ) -or ( [boolean]$ChildItem.step ) ) {
                $StepType = 'group'
                $content = $null
            }
            else {
                $StepType = 'step'
                # $content = $ChildItem.InnerXml
                $content = $ChildItem.OuterXml
            }
            #>
            $results += [PSCustomObject]@{
                Name            = $ChildItem.name
                Level           = $Level
                StepType        = $StepType
                Description     = $ChildItem.description
                continueOnError = $ChildItem.continueOnError
                runIn           = $ChildItem.runIn
                successCodeList = $ChildItem.successCodeList
                retryCount      = $ChildItem.retryCount
                runFromNet      = $ChildItem.runFromNet
                type            = $ChildItem.type
                OrderID         = $OrderID
                # ID              = $ID
                content         = $content
            }

            # if ( ( [boolean]$ChildItem.group ) -or ( [boolean]$ChildItem.step ) ) {
            if ( $StepType -eq 'group' ) {
                $results += Get-SCCMTSStructure -Item $ChildItem -Level ( $Level + 1 ) -OrderID $OrderID # -ParentID $ID
            }
            $OrderID = ( $results | Measure-Object -Maximum OrderID ).Maximum
        }
        return $results
    }

    function Get-VarItem {
        Param (
            [Parameter(Mandatory=$true)]
            $VarItem # = $StepDetails.defaultVarList.variable
        )
        $Result = @{}
        $var = @( $VarItem )[0]
        foreach ( $var in $VarItem ) {
            $Result.Add( $var.name, $var.'#text')
        }
        return $Result
    }

    function Get-ConditionList {
        [cmdletbinding()]
        Param (
            $Item
            ,
            [int]$Level = 0
        )
        # $ChildItem = @( $Item.ChildNodes )[0]
        foreach ( $ChildItem in @( $Item.ChildNodes ) ) {
            switch ( $ChildItem.LocalName ) {
                'operator' {
                    switch ( $ChildItem.type ) {
                        'not' {
                            li -Content "if None of the conditions are true:"
                        }
                        'or' {
                            li -Content "if Any of the conditions are true:"
                        }
                        'and' {
                            li -Content "if All of the conditions are true:"
                        }
                    }
                    "<ul>"
                }
                'osExpressionGroup' {
                    li -Content "Opearing System equals '$( $ChildItem.Name -join "' or '" )'"
                }
                'expression' {
                    switch ( $ChildItem.type ) {
                        'SMS_TaskSequence_FileConditionExpression' {
                            $ConditionVars = Get-VarItem -VarItem $ChildItem.ChildNodes
                            $Path  = ( $ChildItem.ChildNodes | Where-Object { $_.name -eq 'Path' } ).'#text'
                            if ( $ConditionVars.VersionOperator ) {
                                li -Content "File <b>$( $ConditionVars.Path )</b> exist and Version is $( $ConditionVars.VersionOperator )  <b>$( $ConditionVars.Version )</b>"
                            }
                            if ( $ConditionVars.DateTimeOperator ) {
                                li -Content "File <b>$( $ConditionVars.Path )</b> exist and DateTime is $( $ConditionVars.DateTimeOperator )  <b>$( $ConditionVars.DateTime )</b>"
                            }
                        }
                        'SMS_TaskSequence_FolderConditionExpression' {
                            $ConditionVars = Get-VarItem -VarItem $ChildItem.ChildNodes
                            li -Content "Folder <b>$( $ConditionVars.Path )</b> exist"
                        }
                        'SMS_TaskSequence_RegistryConditionExpression' {
                            $ConditionVars = Get-VarItem -VarItem $ChildItem.ChildNodes
                            li -Content "Registry <b>$( $ConditionVars.KeyPath )\$( $ConditionVars.Value )</b> ( $( $ConditionVars.Type ) ) $( $ConditionVars.Operator ) <b>$( $ConditionVars.Data )</b>"
                        }
                        'SMS_TaskSequence_VariableConditionExpression' {
                            $ConditionVars = Get-VarItem -VarItem $ChildItem.ChildNodes
                            li -Content "Task Sequence Variable <b>$( $ConditionVars.Variable )</b> $( $ConditionVars.Operator ) <b>$( $ConditionVars.Value )</b>"
                        }
                        'SMS_TaskSequence_WMIConditionExpression' {
                            $ConditionVars = Get-VarItem -VarItem $ChildItem.ChildNodes
                            li -Content "WMI Query <b>$( $ConditionVars.Query )</b>"
                        }
                        Default {
                            li -Content $( $ChildItem.type ) -Style "color: #FF0000;"
                        }
                    }
                }
                Default {
                    Write-Verbose "LocalName: $( $ChildItem.LocalName )"
                    Write-Verbose "Type: $( $ChildItem.type )"
                }
            }
            if ( ( $ChildItem.LocalName -notin @( 'osExpressionGroup' )) -and ( $ChildItem.type -notin @('SMS_TaskSequence_WMIConditionExpression') ) ) {
                Get-ConditionList -Item $ChildItem
            }
        }
        if ( $Item.LocalName -eq 'operator' ) {
            "</ul>"
        }
    }

    <#
    $TaskSequenceName = 'P00_All_TAS_WindowsUpdates'
    # $TaskSequenceName = 'P03_ALL_TAS_Swisscom-SQLManagementESC-DEV'
    # $TaskSequenceName = 'P00_ALL_TAS_Swisscom-SCCM-PSModules'
    $TaskSequenceName = 'P02_ALL_IMP_OSDeployment_000-PRD'
    # $TaskSequenceName = 'P00_ALL_TAS_taabujo6_test'
    $TaskSequenceName = 'P03_ALL_IMP_ADDSDeployment_001-PRD'
    #>

    # $TaskSequence = Get-CMTaskSequence -Name $TaskSequenceName -WarningAction SilentlyContinue
    $tsID = ( Get-WmiObject -Namespace "ROOT\SMS\site_$( $SiteCode )" -ComputerName $SiteServer -Query "SELECT PackageID FROM SMS_TaskSequencePackage WHERE Name = '$( $TaskSequenceName )'" ).PackageID
    $TaskSequence = [wmi]"\\$( $SiteServer )\root\sms\site_$( $SiteCode ):SMS_TaskSequencePackage.packageID='$( $tsID )'"

    # $TaskSequence.Sequence | Out-File -FilePath 'D:\Users\TAABUJO6\Document\ts.xml'
    [xml]$Sequence = $TaskSequence.Sequence
    $Item = $Sequence.sequence # .group # .group
    $tsitems = Get-SCCMTSStructure -Item $Item -Level 0
    # $tsitems | Out-GridView
    $tsitem = @( $tsitems )[0]
    $HTML = html -Content {
        header -content {
            $css = @"
                body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt;}
                H1  {}
                H2	{}
                H3	{}
                H4	{}
                H5	{}
                H6	{}
                .pagebreak { page-break-before: always; }
                TH  {background-color:LightBlue;padding: 3px; border: 2px solid black;}
                TD  {padding: 3px; border: 1px solid black; vertical-align: top;}
                TABLE	{border-collapse: collapse;}
                pre {
                    white-space: pre-wrap;       /* Since CSS 2.1 */
                    white-space: -moz-pre-wrap;  /* Mozilla, since 1999 */
                    white-space: -pre-wrap;      /* Opera 4-6 */
                    white-space: -o-pre-wrap;    /* Opera 7 */
                    word-wrap: break-word;       /* Internet Explorer 5.5+ */
                }
"@
            style -Content $css
        }
        Body {
            H1 -Content $TaskSequenceName
            H2 -Content "Table of contents"
            $i = 0
            ul -Content {
                # $tsitem = $tsitems | Out-GridView -PassThru
                foreach ( $tsitem in $tsitems ) {
                    $i++
                    li -Content {
                        a -href "#item_$( $tsitem.OrderID )" -Content $tsitem.Name
                    }
                    $i++
                    if ( $tsitem.Level -lt $tsitems[( $tsitem.OrderID )].Level ) {
                        "<ul>"
                    }
                    if ( $tsitem.Level -gt $tsitems[( $tsitem.OrderID )].Level ) {
                        for ($i = 1; $i -le ( $tsitem.Level - $tsitems[( $tsitem.OrderID )].Level ); $i++) {
                            "</ul>"
                        }
                    }
                }
            }
            H2 -Content "Properties" -Id "Properties"
            H3 -Content "General" -Id "Properties_01"
            table -Content {
                tr -Content {
                    td -Style "width: 250px;" -Content "Name:"
                    td -Style "width: 800px;" -Content $TaskSequence.Name
                }
                tr -Content {
                    td -Style "width: 250px;" -Content "Enabled:"
                    td -Style "width: 800px;" -Content $TaskSequence.TsEnabled.ToString().ToUpper()
                }
                tr -Content {
                    td -Content "Description:"
                    td -Content $TaskSequence.Description
                }
                tr -Content {
                    td -Content "Category:"
                    td -Content $TaskSequence.Category
                }
                tr -Content {
                    td -Content "Progress notification text:"
                    if ( [boolean]$TaskSequence.CustomProgressMsg ) {
                        td -Content "Use custom text:<br>$( $TaskSequence.CustomProgressMsg )"
                    }
                    else {
                        td -Content "Use default text:<br>Running &lt;task sequence name&gt;"
                    }
                }
                tr -Content {
                    td -Content "Restart required:"
                    td -Content ( $TaskSequence.RestartRequired -eq 1 ).ToString().toUpper()
                }
                tr -Content {
                    td -Content "Download size (MB):"
                    td -Content $TaskSequence.EstimatedDownloadSizeMB
                }
                tr -Content {
                    td -Content "Estimated run time (minutes):"
                    td -Content $TaskSequence.EstimatedRunTimeMinutes
                }
            }
            H3 -Content "Advanced"
            table -Content {
                if ( [boolean]$TaskSequence.DependentProgram ) {
                    $PackageID = $TaskSequence.DependentProgram.Split(';')[0]
                    $ProgramName = $TaskSequence.DependentProgram.Split(';')[2]
                    $CMPackage = Get-WmiObject -Namespace "ROOT\SMS\site_$( $SiteCode )" -ComputerName $SiteServer -Query "SELECT * FROM SMS_Package WHERE PackageID = '$( $PackageID )' AND PackageType = 0 AND ActionInProgress <> 3"

                    tr -Content {
                        td -Style "width: 250px;" -Content "Run another program first:"
                        td -Style "width: 800px;" -Content "TRUE"
                    }
                    tr -Content {
                        td -Content "Package:"
                        td -Content "$( $PackageID ) - $( $CMPackage.Name )"
                    }
                    tr -Content {
                        td -Content "Program:"
                        td -Content $ProgramName
                    }
                }
                tr -Content {
                    td -Style "width: 250px;" -Content "Suppress task sequence notifications:"
                    td -Style "width: 800px;" -Content ( ( $TaskSequence.ProgramFlags -band 0x400 ) -eq 1 ).ToString().ToUpper()
                }
                tr -Content {
                    td -Content "Disable this task sequence on computers where it is deployed"
                    td -Content "unknown" -Style "color: #FF0000;"
                }
            }

            H2 -Content "Steps" -Id "Steps"
            # $tsitem = $tsitems | Out-GridView -PassThru
            foreach ( $tsitem in $tsitems ) {
                switch ( $tsitem.Level ) {
                    0 {
                        H3 -Id "item_$( $tsitem.OrderID )" -Content {
                            "$( $tsitem.StepType ): $( $tsitem.Name )"
                        }
                    }
                    1 {
                        H4 -Id "item_$( $tsitem.OrderID )" -Content {
                            "$( $tsitem.StepType ): $( $tsitem.Name )"
                        }
                    }
                    2 {
                        H5 -Id "item_$( $tsitem.OrderID )" -Content {
                            "$( $tsitem.StepType ): $( $tsitem.Name )"
                        }
                    }
                    Default {
                        H6 -Id "item_$( $tsitem.OrderID )" -Content {
                            "$( ''.PadLeft( ( $tsitem.Level - 3 ) , ' ' ).Replace(' ', '&nbsp;') )$( $tsitem.StepType ): $( $tsitem.Name )"
                        }
                    }
                }
                if ( $tsitem.StepType -eq 'group' ) {
                    $StepDetails = ( [xml]$tsitem.content ).group
                    $TypeName = 'Group'
                }
                else {
                    $StepDetails = ( [xml]$tsitem.content ).step
                    switch ( $tsitem.type ) {
                        'SMS_TaskSequence_DownloadPackageContentAction' { $TypeName = 'Download Package Content' }
                        'SMS_TaskSequence_InstallApplicationAction'     { $TypeName = 'Install Application' }
                        'SMS_TaskSequence_InstallSoftwareAction'        { $TypeName = 'Install Package' }
                        'SMS_TaskSequence_InstallUpdateAction'          { $TypeName = 'Install Software Updates' }
                        'SMS_TaskSequence_PrestartCheckAction'          { $TypeName = 'Check Readiness' }
                        'SMS_TaskSequence_RebootAction'                 { $TypeName = 'Restart Computer' }
                        'SMS_TaskSequence_RunCommandLineAction'         { $TypeName = 'Run Command Line' }
                        'SMS_TaskSequence_RunPowerShellScriptAction'    { $TypeName = 'Run PowerShell Script' }
                        'SMS_TaskSequence_SetDynamicVariablesAction'    { $TypeName = 'Set Dynamic Variables' }
                        'SMS_TaskSequence_SetVariableAction'            { $TypeName = 'Set Task Sequence Variable' }
                        Default { $TypeName = $tsitem.type }
                    }
                }

                table -Content {
                    tr -Content {
                        td -Style "width: 250px;" -Content "Step-Name:"
                        td -Style "width: 800px;" -Content $tsitem.Name
                    }
                    tr -Content {
                        td -Content "Type:"
                        if ( $tsitem.type -eq $TypeName ) {
                            td -Content $TypeName -Style "color: #FF0000;"
                        }
                        else {
                            td -Content $TypeName
                        }
                    }
                    if ( [boolean]$tsitem.Description ) {
                        tr -Content {
                            td -Content "Description:"
                            td -Content $tsitem.Description
                        }
                    }
                    tr -Content {
                        td -Content "Disable this Step:"
                        td -Content ( ( [boolean]( $StepDetails.disable ) ).ToString().toUpper() )
                    }
                    if ( [boolean]$StepDetails.successCodeList ) {
                        tr -Content {
                            td -Content "Success Codes:"
                            td -Content $StepDetails.successCodeList
                        }
                    }
                    tr -Content {
                        td -Content "Continue on error:"
                        td -Content ( ( [boolean]( $tsitem.continueOnError) ).ToString().ToUpper() )
                    }

                    if ( [boolean]$StepDetails.condition ) {
                        $ConditionText = "this group / step will run if the following conditions are met:<br>"
                        $ConditionText += Get-ConditionList -Item $StepDetails.condition

                        $StepDetails.condition.operator.osConditionGroup
                        tr -Content {
                            td -Content "Conditions:"
                            td -Content $ConditionText
                        }

                    }

                    switch ( $tsitem.type ) {
                        'SMS_TaskSequence_DownloadPackageContentAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable
                            $PackageIDs = @( $StepVars.OSDDownloadDownloadPackages -split ',' )
                            tr -Content {
                                td -Content "Packages:"
                                td -Content {
                                    ul -Content {
                                        # $PackageID = @( $PackageIDs )[0]
                                        foreach ( $PackageID in $PackageIDs ) {
                                            # $CMPackage = Get-CMPackage -Id $PackageID -Fast
                                            $CMPackage = Get-WmiObject -Namespace "ROOT\SMS\site_$( $SiteCode )" -ComputerName $SiteServer -Query "SELECT * FROM SMS_Package WHERE PackageID = '$( $PackageID )' AND PackageType = 0 AND ActionInProgress <> 3"

                                            li -Content "$( $PackageID ) - $( $CMPackage.Name )"
                                        }
                                    }
                                }
                            }
                            tr -Content {
                                td -Content "Place into following location:"
                                switch ( $StepVars.OSDDownloadDestinationLocationType ) {
                                    'custom' {
                                        td -Content $StepVars.OSDDownloadDestinationPath
                                    }
                                    'TSCache' {
                                        td -Content "Task Sequence working directory"
                                    }
                                    Default {
                                        td -Content "Configuration Manager client cache"
                                    }
                                }
                            }
                            if ( [boolean]$StepVars.OSDDownloadDestinationVariable ) {
                                tr -Content {
                                    td -Content "Save path as variable:"
                                    td -Content $StepVars.OSDDownloadDestinationVariable
                                }
                            }
                            tr -Content {
                                td -Content "if a package download fails, continue downloading other packages in the list"
                                td -Content $StepVars.OSDDownloadContinueDownloadOnError.ToUpper()
                            }
                        }
                        'SMS_TaskSequence_InstallApplicationAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable
                            if ( $StepVars.Keys | Where-Object { $_ -match "OSDApp*.DisplayName" } ) {
                                tr -Content {
                                    td -Content "Install the following applications:"
                                    td -Content {
                                        ul -Content {
                                            foreach ( $Key in @( $StepVars.Keys | Where-Object { $_ -match "OSDApp*.DisplayName" }  ) ) {
                                                li -content $StepVars."$( $Key )"
                                            }
                                        }
                                    }
                                }
                            }
                            if ( $StepVars.BaseVariableName ) {
                                tr -Content {
                                    td -Content "Install applications according to dynamic variable list:"
                                    td -Content $StepVars.BaseVariableName
                                }
                            }
                            tr -Content {
                                td -Content "if an application installation fails, continue installing other applications in the list"
                                td -Content $StepVars.ContinueOnInstallError.ToUpper()
                            }
                            tr -Content {
                                td -Content "clear application content from cache after installing"
                                td -Content $StepVars.OSDAppClearCache.ToUpper()
                            }
                            if ( $StepVars.RetryCount ) {
                                tr -Content {
                                    td -Content "number of times to retry"
                                    td -Content $StepVars.RetryCount
                                }
                            }
                        }
                        'SMS_TaskSequence_InstallSoftwareAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable
                            if ( $StepVars.PackageID ) {
                                # $CMPackage = Get-CMPackage -Id $StepVars.PackageID -Fast
                                $CMPackage = Get-WmiObject -Namespace "ROOT\SMS\site_$( $SiteCode )" -ComputerName $SiteServer -Query "SELECT * FROM SMS_Package WHERE PackageID = '$( $StepVars.PackageID )' AND PackageType = 0 AND ActionInProgress <> 3"

                                tr -Content {
                                    td -Content "Package to install:"
                                    td -Content "$( $StepVars.PackageID ) - $( $CMPackage.Name )"
                                }
                                tr -Content {
                                    td -Content "Program:"
                                    td -Content $StepVars._SMSSWDProgramName
                                }
                            }
                            if ( $StepVars.BaseVariableName ) {
                                tr -Content {
                                    td -Content "Install software packages according to dynamic variable list:"
                                    td -Content $StepVars.BaseVariableName
                                }
                                tr -Content {
                                    td -Content "if installation of a software package fails, continue installing other packages in the list"
                                    td -Content $StepVars.ContinueOnInstallError.ToUpper()
                                }
                            }
                        }
                        'SMS_TaskSequence_InstallUpdateAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable
                            $StepVars.Keys
                            tr -Content {
                                td -Content "install software updates based on the type of software update deployment:"
                                if ( $StepVars.SMSInstallUpdateTarget -eq 'All' ) {
                                    td -Content "Available for installation - All software updates"
                                }
                                else {
                                    td -Content "Required for installation - Mandatory software updates only"
                                }
                            }
                            tr -Content {
                                td -Content "Evaluate software updates from cached scan results"
                                td -Content $StepVars.SMSTSSoftwareUpdateScanUseCache.ToUpper()
                            }
                            if ( $StepVars.RetryCount ) {
                                tr -Content {
                                    td -Content "number of times to retry"
                                    td -Content $StepVars.RetryCount
                                }
                            }
                        }
                        'SMS_TaskSequence_PrestartCheckAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable
                            if ( $StepVars.OSDCheckMemory -eq 'true' ) {
                                tr -content {
                                    td -Content "Minimum Memory (MB):"
                                    td -Content $StepVars.OSDMemory
                                }
                            }
                            if ( $StepVars.OSDCheckProcessorSpeed -eq 'true' ) {
                                tr -content {
                                    td -Content "Minimum Processor speed (MHz):"
                                    td -Content $StepVars.OSDProcessorSpeed
                                }
                            }
                            if ( $StepVars.OSDCheckFreeDiskSpace -eq 'true' ) {
                                tr -content {
                                    td -Content "Minimum free disk space (MB):"
                                    td -Content $StepVars.OSDFreeDiskSpace
                                }
                            }
                            if ( $StepVars.OSDCheckOSType -eq 'true' ) {
                                tr -content {
                                    td -Content "Current OS to be refreshed is:"
                                    td -Content $StepVars.OSDOSType
                                }
                            }
                            if ( $StepVars.OSDCheckOSArchitecture -eq 'true' ) {
                                tr -content {
                                    td -Content "Architecture of current OS:"
                                    td -Content $StepVars.OSDOSArchitecture
                                }
                            }
                            if ( $StepVars.OSDCheckMinOSVersion -eq 'true' ) {
                                tr -content {
                                    td -Content "Minimum OS Version:"
                                    td -Content $StepVars.OSDMinOSVersion
                                }
                            }
                            if ( $StepVars.OSDCheckMaxOsVersion -eq 'true' ) {
                                tr -content {
                                    td -Content "Maximum OS Version:"
                                    td -Content $StepVars.OSDMaxOSVersion
                                }
                            }
                            if ( $StepVars.OSDCheckCMClientMinVersion -eq 'true' ) {
                                tr -content {
                                    td -Content "Minimum Client Version:"
                                    td -Content $StepVars.OSDCMClientMinVersion
                                }
                            }
                            if ( $StepVars.OSDCheckOSLanguageID -eq 'true' ) {
                                tr -content {
                                    td -Content "Language of current OS:"
                                    td -Content $StepVars.OSDOSLanguageID
                                }
                            }
                            tr -content {
                                td -Content "AC Power plugged in:"
                                td -Content $StepVars.OSDCheckPowerState.ToUpper()
                            }
                            tr -content {
                                td -Content "Network adapter connected:"
                                td -Content $StepVars.OSDCheckNetworkConnected.ToUpper()
                            }
                            tr -content {
                                td -Content "Network adapter is not wireless:"
                                td -Content $StepVars.OSDCheckNetworkWired.ToUpper()
                            }
                            <#
                            tr -content {
                                td -Content "Computer is in UEFI mode:"
                                td -Content $StepVars.OSDCheckDeviceUEFI.ToUpper()
                            }
                            #>
                        }
                        'SMS_TaskSequence_RebootAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable

                            tr -Content {
                                td -Content "Specify what to run after restart:"
                                switch ( $StepVars.SMSRebootTarget ) {
                                    'HD' {
                                        td -Content "The currently installed default operating system"
                                    }
                                    Default {
                                        td -Content "The boot image assigned to this task sequence"
                                    }
                                }
                            }
                            if ( [boolean]$StepVars.SMSRebootMessage ) {
                                tr -Content {
                                    td -Content "Notification message:"
                                    td -Content $StepVars.SMSRebootMessage
                                }
                                tr -Content {
                                    td -Content "message display time-out (seconds):"
                                    td -Content $StepVars.SMSRebootTimeout
                                }
                            }
                        }
                        'SMS_TaskSequence_RunCommandLineAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable

                            tr -Content {
                                td -Content "Command line:"
                                td -Content {
                                    pre -content {
                                        $StepVars.CommandLine
                                    }
                                }
                            }
                            if ( [boolean]$StepVars.SMSTSRunCommandLineOutputVariableName ) {
                                tr -content {
                                    td -content "Output to task sequence variable:"
                                    td -Content $StepVars.SMSTSRunCommandLineOutputVariableName
                                }
                            }
                            tr -Content {
                                td -Content "Disable 64 bit file system redirection:"
                                td -Content $StepVars.SMSTSDisableWow64Redirection.ToUpper()
                            }
                            if ( $StepVars.SMSTSRunCommandLineAsUser ) {
                                tr -Content {
                                    td -Content "Run this step as the following account:"
                                    td -Content $StepVars.SMSTSRunCommandLineUserName
                                }
                            }
                        }
                        'SMS_TaskSequence_RunPowerShellScriptAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable

                            $PSSourceScript64 = $StepVars.OSDRunPowerShellScriptSourceScript
                            if ( [boolean]$StepVars.OSDRunPowerShellScriptPackageID ) {
                                $PSPackage = Get-WmiObject -Namespace "ROOT\SMS\site_$( $SiteCode )" -ComputerName $SiteServer -Query "SELECT * FROM SMS_Package WHERE PackageID = '$( $StepVars.OSDRunPowerShellScriptPackageID )' AND PackageType = 0 AND ActionInProgress <> 3"
                                tr -Content {
                                    td -Content "Script Source Package:"
                                    td -Content "$( $StepVars.OSDRunPowerShellScriptPackageID ), $( $PSPackage.Name )"
                                }
                                tr -Content {
                                    td -Content "Script name:"
                                    td -Content "$( $StepVars.OSDRunPowerShellScriptScriptName )"
                                }
                            }
                            if ( [boolean]$PSSourceScript64 ) {
                                $PSSourceScript = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String( $PSSourceScript64 ) )
                                tr -content {
                                    td -content "Enter a PowerShell script:"
                                    td -Content {
                                        pre -content {
                                            $PSSourceScript
                                        }
                                    }
                                }
                            }
                            if ( [boolean]$StepVars.OSDRunPowerShellScriptParameters ) {
                                tr -Content {
                                    td -Content "Script parameters:"
                                    td -Content "$( $StepVars.OSDRunPowerShellScriptParameters )"
                                }
                            }
                            tr -content {
                                td -content "PowerShell execution policy:"
                                td -Content $StepVars.OSDRunPowerShellScriptExecutionPolicy
                            }
                            if ( [boolean]$StepVars.OSDRunPowerShellScriptOutputVariableName ) {
                                tr -content {
                                    td -content "Output to task sequence variable:"
                                    td -Content $StepVars.OSDRunPowerShellScriptOutputVariableName
                                }
                            }
                            if ( [boolean]( $StepDetails.timeout ) ) {
                                tr -Content {
                                    td -Content "TimeOut"
                                    td -Content ( $StepDetails.timeout / 60 )
                                }
                            }
                        }
                        'SMS_TaskSequence_SetDynamicVariablesAction' {
                            $vars = ( [xml]$StepDetails.defaultVarList.variable.'#text' ).Rules.ChildNodes
                            $var = $vars[0]
                            tr -content {
                                td -Content "Dynamic rules and variables:"
                                td -Content {
                                    "The following rules and variables will be evaluated in order:"
                                    ul {
                                        foreach ( $var in $vars ) {
                                            li "Set $( $var.Variables.Variable.Name ) = $( $var.Variables.Variable.'#text' )"
                                        }
                                    }
                                }
                            }
                        }
                        'SMS_TaskSequence_SetVariableAction' {
                            $StepVars = Get-VarItem -VarItem $StepDetails.defaultVarList.variable

                            tr -Content {
                                td -Content "Task Sequence Variable:"
                                td -Content $StepVars.VariableName
                            }
                            tr -Content {
                                td -Content "Do not display this value:"
                                td -Content $StepVars.DoNotShowVariableValue
                            }
                            tr -Content {
                                td -Content "Task Sequence Variable:"
                                if ( $StepVars.DoNotShowVariableValue -eq 'true' ) {
                                    td -Content ''.PadLeft( $StepVars.VariableValue.Length, '*' )
                                }
                                else {
                                    td -Content $StepVars.VariableValue
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    $HTML | Out-File -FilePath $FilePath
}

# $TaskSequence = Get-CMTaskSequence -Name $TaskSequenceName -Verbose
$ts = [wmiclass]"\\$( $SiteServer )\root\sms\site_$( $SiteCode ):sms_tasksequence"
$ts = [wmi]"\\$( $SiteServer )\root\sms\site_$( $SiteCode ):sms_tasksequencepackage.packageID='$( $TaskSequence.PackageID )'"
$tsID = ( Get-WmiObject -Namespace "ROOT\SMS\site_$( $SiteCode )" -ComputerName $SiteServer -Query "SELECT PackageID FROM SMS_TaskSequencePackage WHERE Name = '$( $TaskSequenceName )'" ).PackageID
$ts = [wmi]"\\$( $SiteServer )\root\sms\site_$( $SiteCode ):SMS_TaskSequencePackage.packageID='$( $tsID )'"
[xml]$ts.Sequence
[xml]$tsid.Sequence

$ex = $ts.ExportXml()
$TaskSequences = Get-CMTaskSequence -Fast -verbose
$TaskSequences.Count
$TaskSequence = @( $TaskSequences )[0]
foreach ( $TaskSequence in $TaskSequences ) {
    $TaskSequenceName = $TaskSequence.Name
    Write-Host $TaskSequenceName
    $FilePath = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\_TS\$( $TaskSequenceName ).html"
    New-SCCMTaskSequenceDocumentation -SiteCode P00 -SiteServer 'poap0cas-1.scmgmt.net' -TaskSequenceName $TaskSequenceName -FilePath $FilePath
}

