# This script will stop relevant services/tasks, uninstall Chocolatey Package Manager, clean up the OS then shutdown the VM to prepare it for snapshotting
# Requires the VMware OS Optmization Tool for final clean up process - https://flings.vmware.com/vmware-os-optimization-tool

# Stop and Disable Services
Write-Host "Stopping and Disabling Services"
Stop-Service -Name bits
Stop-Service -Name wuauserv
#Stop-Service -Name ClickToRunSvc
Set-Service -Name bits -StartupType Disabled
Set-Service -Name wuauserv -StartupType Disabled
#Set-Service -Name ClickToRunSvc -DisplayName "Microsoft Office Click-to-Run Service" -StartupType Disabled
Set-Service -Name gupdate -DisplayName "Google Update Service (gupdate)" -StartupType Disabled
Set-Service -Name gupdatem -DisplayName "Google Update Service (gupdatem)" -StartupType Disabled
Set-Service -Name edgeupdate -DisplayName "Microsoft Edge Update Service (edgeupdate)" -StartupType Disabled
Set-Service -Name edgeupdatem -DisplayName "Microsoft Edge Update Service (edgeupdatem)" -StartupType Disabled

# Disable Scheduled Tasks
Write-Host "Disabling Scheduled Tasks"
Disable-ScheduledTask -TaskName "Adobe Acrobat Update Task"
Disable-ScheduledTask -TaskName "GoogleUpdateTaskMachineCore"
Disable-ScheduledTask -TaskName "GoogleUpdateTaskMachineUA"
Disable-ScheduledTask -TaskName "MicrosoftEdgeUpdateTaskMachineCore"
Disable-ScheduledTask -TaskName "MicrosoftEdgeUpdateTaskMachineUA"

# Uninstall Chocolatey Package Manager
Write-Host "Uninstalling Chocolatey Package Manager"
Remove-Item -Path "C:\ProgramData\chocolatey" -Recurse -Force

# Clean up Image
Write-Host "Cleaning up Image"
#Remove-Item -Path "C:\Users\Public\Desktop\*" -Recurse -Force
Remove-Item -Path $Env:TEMP\* -Recurse -Force
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force
Remove-Item -Path "C:\Windows\SoftwareDistribution\*" -Recurse -Force
cd "C:\master"
.\VMwareOSOptimizationTool.exe -f 0 1 2 3 4 9 10 11

# Set Execution Policy
Write-Host "Setting PowerShell Execution Policy to Restricted"
Set-ExecutionPolicy Restricted -Force

# Shutdown VM
Write-Host "Shutting down Computer"
Stop-Computer -ComputerName localhost
