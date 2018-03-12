<#
  Copyright (c) 2017-2018 Francois Gendron <fg@frgn.ca>
  MIT License

  create_templateVM.ps1
  PowerShell script that creates, configures, and exports a template Hyper-V VM


  Requirements:
  PuTTY http://www.putty.org/
#>

################################################################################
# Set template virtual machine parameters
$VirtualMachineName = "_template"
$VirtualHardDriveSize = 10GB
$VirtualMachineMemory = 2GB
$VirtualSwitchName = "vSwitch"
########################
# Set internal variables
$currentFolder = (Resolve-Path .\).Path
$InstallationMediaLocation = $currentFolder+"\ISOs\ubuntu-16.04.4-server-amd64.iso"
$exportPath = $currentFolder+"\Templates"
$VirtualMachineLocation = $currentFolder+"\VMs"
$VirtualMachineGeneration = 2
$VirtualHardDriveLocation = "$VirtualMachineLocation\$VirtualMachineName\Virtual Hard Disks\VHD.vhdx"
$displayRAMsizeGB = $VirtualMachineMemory / 1024 /1024 / 1024
$displayVHDsizeGB = $VirtualHardDriveSize / 1024 /1024 / 1024

# Display VM parameters
Write-Host "
########################

  create_templateVM

########################

  VM Name: $VirtualMachineName
  VM VHD:   $displayVHDsizeGB GB
  VM RAM:    $displayRAMsizeGB GB
Only continue if the parameters are correct
#  -> just press Enter
## -> do something, then press Enter"

# Chance to stop before proceeding
Pause

# Display instructions
Write-Host "
########################

Wait time  1 min (   1% when done)
localhost console will open"

# Create virtual machine
New-VM -Name $VirtualMachineName -MemoryStartupBytes $VirtualMachineMemory -Generation $VirtualMachineGeneration -NewVHDPath $VirtualHardDriveLocation -NewVHDSizeBytes $VirtualHardDriveSize -Path $VirtualMachineLocation -SwitchName $VirtualSwitchName > $null

# Add DVD drive with installation media to virtual machine
Add-VMDvdDrive -VMName $VirtualMachineName -ControllerNumber 0 -ControllerLocation 1 -Path $InstallationMediaLocation

# Set virtual machine to boot from DVD drive
$DVDDrive = Get-VMDvdDrive -VMName $VirtualMachineName
Set-VMFirmware -VMName $VirtualMachineName -FirstBootDevice $DVDDrive

# Set virtual machine to disable SecureBoot
Set-VMFirmware -VMName $VirtualMachineName -EnableSecureBoot Off

# Create a pre-install snapshot
Checkpoint-VM -VMName $VirtualMachineName -SnapshotName "pre-install" > $null

# Start virtual machine
Start-VM -Name $VirtualMachineName > $null

# Display ubuntu installation instructions
Write-Host '
########################

  Installation
  GNU GRUB
#  Select <Install Ubuntu Server>
  Select a language
#  Select <English>
  Select your location
## Select <Canada>
  Configure the keyboard
  Detect keyboard layout:
#  Select <No>
  Country of origin for the keyboard:
## Select <French (Canada)>
  Keyboard layout:
#  Select <French (Canada)>

Wait time  1 min (   3% when done)

  Hostname:
#  Type "ubuntu"
  Set up users and passwords
  Full name for the new user:
#  Press Enter
  Username for your account:
## Type "username"
  Choose a password for the new user:
## Type "password"
  Re-enter password to verify:
## Type "password"
  Encrypt your home directory?
#  Select <No>
  Configure the clock
  Is this time zone correct?
## Select <No>
  Select your time zone:
## Select <Eastern>
  Partition disks
  Partitioning method:
#  Select <Guided - use entire disk and set up LVM>
  Select disk to partition:
#  Select <SCSI1 (0,0,0) (sda) - 10.7 GB Msft Virtual Disk>
  Write the changes to disks and configure LVM?
## Select <Yes>
  Amount of volume group to use for guided partitioning:
#  Press Enter
  Force UEFI installation?
## Select <Yes>
  Finish partitioning and write changes to disk
  Write the changes to disks?
## Select <Yes>

Wait time  5 min (  11% when done)

  Configure the package manager
  HTTP proxy information (blank for none):
#  Press Enter

Wait time  1 min (  12% when done)

  Configure tasksel
  How do you want to manage upgrades on this system?
## Select <Install security updates automatically>
  Software selection
  Choose software to install:
## Select with spacebar <Samba file server> and <openSSH server>

Wait time 25+min (  51% when done)

  Finish the installation
#  Select <Continue>

Wait time  1 min (  52% when done)'

# Connect to virtual machine video console
vmconnect.exe localhost $VirtualMachineName

# While tickcount of virtual machine keeps going up (reboots too quickly, cannot catch "Off" state)
$previousTickcount = (Get-VM -Name $VirtualMachineName).Uptime.Ticks
while((Get-VM -Name $VirtualMachineName).Uptime.Ticks -gt $previousTickcount)
{
    # Update tickcount
    $previousTickcount = (Get-VM -Name $VirtualMachineName).Uptime.Ticks
}

# Make sure virtual machine stays stopped
Stop-VM $VirtualMachineName -Force > $null

# While virtual machine is not off
while((Get-VM -Name $VirtualMachineName).State -ne "Off")
{
    # Wait a second
    sleep(1)
}

# Create a post-install snapshot
Checkpoint-VM -VMName $VirtualMachineName -SnapshotName "post-install" > $null

# Start virtual machine
Start-VM $VirtualMachineName > $null

# Display instructions
Write-Host '
########################

  Login with localhost console (username:password)
## Type "username"
## Type "password"
  Find IP address (192.168.1.???)
## Type "ifconfig"
## Type the IP address bellow when found'

# Get temporary IP address
$tempIP = Read-Host -Prompt "Temporary IP address"

# While virtual machine does not respond to ping
while(-Not(Test-Connection $tempIP -Count 1 -Quiet))
{
    # Display instructions
    Write-Host "$tempIP unreachable"
    
    # Get temporary IP address
    $tempIP = Read-Host -Prompt "Temporary IP address"
}

# ToDo: Close localhost console
# ToDo: wget a script that does the following instead of pasting commands

# Display instructions 1 of 5
$command = 'sudo ufw allow ssh > /dev/null 2>&1 && sudo ufw allow 137 > /dev/null 2>&1 && sudo ufw allow 138 > /dev/null 2>&1 && sudo ufw allow 139 > /dev/null 2>&1 && sudo ufw allow 445 > /dev/null 2>&1 && sudo ufw --force enable > /dev/null 2>&1 && sudo sed -i "s#iface eth0 inet dhcp#iface eth0 inet static#" /etc/network/interfaces > /dev/null 2>&1 && echo -e "  address 192.168.1.100\n  netmask 255.255.255.0\n  gateway 192.168.1.1\n  dns-nameservers 8.8.8.8 8.8.4.4" | sudo tee -a /etc/network/interfaces > /dev/null 2>&1 && echo -e "[root]\n   comment = read only\n   path = /\n   browsable = yes\n   read only = yes\n   guest ok = yes" | sudo tee -a /etc/samba/smb.conf > /dev/null 2>&1'
$command | clip
Write-Host '
########################

## Paste "'$command'"'
Write-Host '## Type "password"' # ToDo: sudo for this session

# Open ssh session to temporary IP of virtual machine with PuTTY with username:password
cd "C:\Program Files\PuTTY"
.\putty.exe -ssh username@$tempIP -pw "password"

# Wait for user to be ready to continue
Pause

# Display instructions 2 of 5
$command = "sudo apt-get update > /dev/null 2>&1 && sudo apt-get -y upgrade > /dev/null 2>&1"
$command | clip
Write-Host '
########################

## Paste "'$command'"'
Write-Host "
Wait time 15+min (  75% when done)"

# Wait for user to be ready to continue
Pause

# Display instructions 3 of 5
$command = "sudo apt-get -y install --install-recommends linux-virtual-lts-xenial > /dev/null 2>&1"
$command | clip
Write-Host '
########################

## Paste "'$command'"'
Write-Host "
Wait time  5 min (  83% when done)"

# Wait for user to be ready to continue
Pause

# Display instructions 4 of 5
$command = "sudo apt-get -y install --install-recommends linux-tools-virtual-lts-xenial linux-cloud-tools-virtual-lts-xenial > /dev/null 2>&1"
$command | clip
Write-Host '
########################

## Paste "'$command'"'
Write-Host "
Wait time  1 min ( 85% when done)"

# Wait for user to be ready to continue
Pause

# Display instructions 5 of 5
$command = "sudo shutdown now"
$command | clip
Write-Host '
########################

## Paste "'$command'"'

Write-Host "
Wait time 10 min (100% when done)
ssh session will close"

# While virtual machine is not off
while((Get-VM $VirtualMachineName).State -ne "Off")
{
    # Wait 1 second
    sleep(1)
}

# Create an official template snapshot
Checkpoint-VM -VMName $VirtualMachineName -SnapshotName "template" > $null

# Export virtual machine
Export-VM -Name $VirtualMachineName -Path $exportPath

# Remove virtual machine template from Hyper-V
Remove-VM $VirtualMachineName -Force

# Delete virtual machine folder
Remove-Item -Recurse -Force "$VirtualMachineLocation\$VirtualMachineName"

# Display instructions
Write-Host "
########################

Done

########################"
