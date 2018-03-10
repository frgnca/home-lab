<#
  Copyright (c) 2017-2018 Francois Gendron <fg@frgn.ca>
  MIT License

  clone_templateVM.ps1
  PowerShell script that imports and starts a virtual machine
  from an exported template


  Requirements:
  PuTTY http://www.putty.org/
#>

################################################################################
# Set new virtual machine parameters
$VirtualMachineName = "test1" # ToDo: test if already exists
$VirtualHardDriveSize = 10GB #[10GB+] # ToDo: auto resize in ubuntu
$VirtualMachineMemory = 2GB #[2GB+]
$VirtualSwitchName = "vSwitch"
$VirtualMachineLocation = "D:\VMs"
$startAction = "StartIfRunning" #[Nothing, Start, StartIfRunning]
$VirtualMachineIP = "192.168.1.31" # ToDo: Add dhcp posibility
$VirtualMachineUser = "test"
$templateVMName = "_template"
########################
# Set internal variables
$VirtualMachineGeneration = 2
$templateFolder = "D:\frgnca\Documents\_fg\VM"
$bashFolder = "D:\frgnca\Documents\_fg\Scripts\bash"
$VirtualMachineFolder = "$VirtualMachineLocation\$VirtualMachineName"
$SnapshotFolder = $VirtualMachineFolder+"\Snapshots"
$VHDFolder = $VirtualMachineFolder+"\Virtual Hard Disks"
$templateConfig = (Get-Item "$templateFolder\$templateVMName\Virtual Machines\*.vmcx").FullName
$fileContent = Get-Content "$bashFolder\setupTemplate.sh.old"
$bashProfile = "$bashFolder\.bash_profile"
$setupTemplate = "$bashFolder\setupTemplate.sh"
$displayRAMsizeGB = $VirtualMachineMemory / 1024 /1024 / 1024
$displayVHDsizeGB = $VirtualHardDriveSize / 1024 /1024 / 1024

# Display VM parameters
Write-Host "
########################

  clone_templateVM

########################

 VM to create: $VirtualMachineName
          VHD:  $displayVHDsizeGB GB
          RAM:   $displayRAMsizeGB GB
           IP: $VirtualMachineIP
  StartAction: $startAction
         User: $VirtualMachineUser
Only continue if the parameters are correct [CTRL+C to cancel]"

# Chance to stop before proceeding
Pause

# Function to write unix style files <https://picuspickings.blogspot.ca/2014/04/out-unix-function-to-output-unix-text_17.html>
function Out-Unix
{
    param ([string] $Path)

    begin 
    {
        $streamWriter = New-Object System.IO.StreamWriter("$Path", $false)
    }
    
    process
    {
        $streamWriter.Write(($_ | Out-String).Replace("`r`n","`n"))
    }
    end
    {
        $streamWriter.Flush()
        $streamWriter.Close()
    }
}

# ToDo+: Check parameters validity, duplicate host/vm name, IP address, folder, etc.

# Display instructions
Write-Host '########################

Wait time 5 min ( 83% when done)
'

# Import virtual machine template
Import-VM -Path $templateConfig -Copy -GenerateNewId -SmartPagingFilePath $VirtualMachineFolder -SnapshotFilePath $SnapshotFolder -VhdDestinationPath $VHDFolder -VirtualMachinePath $VirtualMachineFolder > $null

# Rename virtual machine
Rename-VM -Name $templateVMName -NewName $VirtualMachineName

# Connect virtual machine to network
Connect-VMNetworkAdapter -VMName $VirtualMachineName -SwitchName $VirtualSwitchName

# Resize VHD
Resize-VHD -Path $VHDFolder"\VHD.vhdx" -SizeBytes $VirtualHardDriveSize

# Set virtual machine to boot from virtual hard drive
$VHD = Get-VMHardDiskDrive -VMName $VirtualMachineName
Set-VMFirmware -VMName $VirtualMachineName -FirstBootDevice $VHD

# Change virtual machine memory
Set-VMMemory $VirtualMachineName -StartupBytes $VirtualMachineMemory

# Set virtual machine to disable SecureBoot
Set-VMFirmware -VMName $VirtualMachineName -EnableSecureBoot Off

# Set virtual machine start action
Set-VM -Name $VirtualMachineName -AutomaticStartAction $startAction

# Set virtual machine stop action (autosave)
Set-VM -Name $VirtualMachineName -AutomaticStopAction Save

# If integration service is not enabled
$VMIntegr = Get-VMIntegrationService -VMName $VirtualMachineName | Where-Object -Property Name -EQ "Interface de services d’invité" | Select-Object Enabled
if($VMIntegr.Enabled -ne "True")
{
    # Enable integration service
    Enable-VMIntegrationService -Name "Interface de services d’invité" -VMName $VirtualMachineName #-Name "guest service interface"
}

# Start virtual machine
Start-VM $VirtualMachineName

# While virtual machine does not respond to ping
while(-Not(Test-Connection "192.168.1.100" -Count 1 -Quiet))
{
    # Do nothing, try again
}

# Wait 5 seconds after virtual machine starts responding to ping
# ToDo: find something else more acceptable
sleep(5)

# Copy setupTemplate.sh.old to setupTemplate.sh
$fileContent | Out-Unix -Path $setupTemplate

# Find and replace line containing "newHostname=" with $VirtualMachineName
$i = -1
$find = "newHostname="
$replace = "newHostname=""$VirtualMachineName"""
$fileContent | ForEach-Object {$i++; if($_ -match $find){ $fileContent[$i] = $replace; $fileContent | Out-Unix -Path $setupTemplate } }

# Find and replace line containing "newUser=" with $VirtualMachineUser
$i = -1
$find = "newUser="
$replace = "newUser=""$VirtualMachineUser"""
$fileContent | ForEach-Object {$i++; if($_ -match $find){ $fileContent[$i] = $replace; $fileContent | Out-Unix -Path $setupTemplate } }

# Find and replace line containing "newIP=" with $VirtualMachineIP
$i = -1
$find = "newIP="
$replace = "newIP=""$VirtualMachineIP"""
$fileContent | ForEach-Object {$i++; if($_ -match $find){ $fileContent[$i] = $replace; $fileContent | Out-Unix -Path $setupTemplate } }

# Copy setupTemplate.sh from localhost to virtual machine
$toVM = "/home/username/"
Copy-VMFile $VirtualMachineName -SourcePath $setupTemplate -DestinationPath $toVM -CreateFullPath -FileSource Host -Force

# Copy .bash_profile from localhost to virtual machine
$scriptCall = "sudo ~/./setupTemplate.sh"
$scriptCall | Out-Unix -Path $bashProfile
$toVM = "/home/username/"
Copy-VMFile $VirtualMachineName -SourcePath $bashProfile -DestinationPath $toVM -CreateFullPath -FileSource Host -Force

# Open ssh session to template vm with PuTTY
cd "C:\Program Files\PuTTY"
.\putty.exe -ssh username@192.168.1.100 -pw "password"

# Display instructions
Write-Host '########################

## Type "password"
## Type a newly invented password
## Retype your newly invented password

Wait time  1+min ( 99% when done)
ssh session will close
'

# While virtual machine is not off
while((Get-VM $VirtualMachineName | Select-Object -Property State).State -ne "Off")
{
    # Wait for a second
    sleep(1)
}

# Display instructions
Write-Host "########################

Wait time  1 min (100% when done)
"

# ToDo: close old putty window

# Create snapshot "base"
Get-VM -Name $VirtualMachineName | Checkpoint-VM -SnapshotName "base"

# Start virtual machine
Start-VM $VirtualMachineName

# While virtual machine does not respond to ping
while(-Not(Test-Connection $VirtualMachineIP -Count 1 -Quiet))
{
    # Do nothing, try again
}

# Wait 5 seconds after virtual machine starts responding to ping
# ToDo: how to confirm ssh request won't be too soon?
sleep(10)

# Display instructions
Write-Host "########################

Done

########################"

# Open ssh session to newly configured virtual machine with PuTTY
cd "C:\Program Files\PuTTY"
.\putty.exe -ssh $VirtualMachineUser@$VirtualMachineIP