$goldenname = "goldenimage vm name"
$poolname = "horizon_desktop_pool"
$vcenterName = "vcenternamehere"
$horizonServerName = "horizon server"
$goldenLocalAdminUN = "Administrator"
$goldenLocalAdminPW = "Admin password here"
$goldenLocalPathToUpdate = "c:\master\updater\updateWin.ps1" # no spaces please
$goldenLocalPathToEndUpdate = "c:\master\updater\endUpdateWin.ps1" #no spaces please

$creds = get-credential -Message "Enter creds domain\username format only"
while (-not ($vc))
{
	$vc = connect-viserver "$vcenterName" -Credential $creds
	if (-not ($vc))
	{
		Write-Host "creds wrong"
		exit 1
	}
}
while (-not ($hvServer))
{
	$hvServer = Connect-HVServer "$horizonServerName" -Credential $creds
	if (-not ($hvServer))
	{
		Write-Host "creds wrong"
		exit 1
	}
}


$vm = get-vm $goldenname
$vm | start-vm
$vm | wait-tools
Start-Sleep -Seconds 120


#do the updates here
Write-Host "Running update script"
$vm | Invoke-VMScript -ScriptText 'Start-Process -wait PowerShell -ArgumentList " -NoProfile -ExecutionPolicy Bypass -File $goldenLocalPathToUpdate" -Verb RunAs' -ScriptType powershell -Guestuser $goldenLocalAdminUN -GuestPassword "$goldenLocalAdminPW"
Start-Sleep -Seconds 360
Write-Host "1st Reboot"
$vm | Restart-VMguest -Confirm:$false | wait-tools
Start-Sleep -Seconds 360
Write-Host "Running update script"
$vm | Invoke-VMScript -ScriptText 'Start-Process -wait PowerShell -ArgumentList " -NoProfile -ExecutionPolicy Bypass -File $goldenLocalPathToUpdate" -Verb RunAs' -ScriptType powershell -Guestuser $goldenLocalAdminUN -GuestPassword "$goldenLocalAdminPW"
Write-Host "2nd Reboot"
$vm | Restart-VMguest -Confirm:$false | wait-tools
Start-Sleep -Seconds 360
write-host "cleanup script"
$vm | Invoke-VMScript -ScriptText 'Start-Process -wait PowerShell -ArgumentList " -NoProfile -ExecutionPolicy Bypass -File $goldenLocalPathToEndUpdate" -Verb RunAs' -ScriptType powershell -Guestuser administrator -GuestPassword "replicate this master1!"
while (-not ((get-vm $goldenname).powerstate -eq "PoweredOff"))
{
	Start-Sleep -Seconds 60
}

Start-Sleep -Seconds 60
$snapshotname = "$(get-date -Format "MM-dd-yyy hhmm")"
$vm | New-Snapshot -name $snapshotname
if (($vm | Get-Snapshot).count -gt 3)
{
	($vm | Get-Snapshot)[0] | Remove-Snapshot -Confirm:$false
}

####  Get horizon services
$services1=$Global:hvServices = $hvServer.ExtensionData
$csService = new-object VMware.Hv.ConnectionServerService
$csService.ConnectionServer_List($hvServices)

#### get the desktop pool ids
$queryservice = New-Object VMware.Hv.QueryServiceService
$defn = new-object VMware.Hv.QueryDefinition
$defn.QueryEntityType = 'DesktopSummaryView'
$defn.Filter = New-Object VMware.Hv.QueryFilterEquals -property @{ 'MemberName' = 'desktopSummaryData.name'; 'value' = $poolname }
$desktoppool = ($queryservice.QueryService_Create($services1, $defn)).results
$desktopppoolvcenterid = $desktoppool.desktopsummarydata.VirtualCenter

#### use desktop pool id to get the list of vm's that can be used

#$services1.BaseImageVm.BaseImageVm_List($desktopppoolvcenterid,$null)
$baseimagevmlist = $services1.BaseImageVm.BaseImageVm_List($desktopppoolvcenterid,$null)
#$baseimagevmlist.IncompatibleReasons
#$baseimagevmlist | where { $_.IncompatibleReasons.InUseByDesktop -eq $false -and $_.IncompatibleReasons.InstantInternal -eq $false -and $_.IncompatibleReasons.ViewComposerReplica -eq $false }

#### from the above list get the golden vm and its snapshots
$Desktopbaseimagevm = $baseimagevmlist | where { $_.name -eq "$goldenname" }
$desktopsnapshotlist = $services1.BaseImageSnapshot.BaseImageSnapshot_List($Desktopbaseimagevm.id)

#### instant clone specific snapshots get latest one
$desktopICsnapshot = ($desktopsnapshotlist | sort-object createtime -Descending)[0] #$desktopsnapshotlist | where-object { $_.name -eq $snapshotname }

#### get the desktop pool config
$queryService = New-Object VMware.Hv.QueryServiceService
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryEntityType = 'MachineSummaryView'
$defn.filter = New-Object VMware.Hv.QueryFilterEquals -property @{ 'memberName' = 'base.desktop'; 'value' = $desktoppool.id }
$QueryResults = $queryService.Queryservice_create($Services1, $defn)
$desktopmachinelist = $queryresults.results

#### push the new instant clone snapshot now or uncomment to set a maintenance window to do the push
#$datetime = [DateTime]"mm-dd-yyyy 10:00:00AM"
$desktopimagepushspec = new-object VMware.Hv.DesktopPushImageSpec
$desktopimagepushspec.settings = new-object vmware.hv.DesktopPushImageSettings
$desktopimagepushspec.ParentVm = $desktopbaseimagevm.id
$desktopimagepushspec.snapshot = $desktopICsnapshot.id
#$desktopimagepushspec.settings.StartTime = $datetime
$desktopimagepushspec.settings.LogoffSetting = "WAIT_FOR_LOGOFF"
$desktopimagepushspec.settings.StopOnFirstError = $true


$services1.Desktop.Desktop_SchedulePushImage($desktoppool.id, $desktopimagepushspec)


Disconnect-VIServer -Confirm:$false
Disconnect-HVServer -Confirm:$false
