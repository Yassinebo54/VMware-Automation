## READ_ME
## The script consist of two section, The first section should be filled with ESXI Server and VM parameters, before running the script.
## The second section contains the main methods, which are executed on the server.
## To run this script on powershell, first you must install PowerCLI using (Install-Module -Name VMware.PowerCLI -Scope CurrentUser) command in Powershell.
## Or by running (Install-Module -Name VMware.PowerCLI -Force -AllowClobber) command in Powershell.
## To run this script on powershell, run (Start-Process -FilePath "Path to this script") command in Powershell.
## If error appears due to invalid SSL Certificate, run (Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore) command in Powershell, before running the previous command.
## If error appears due to PowerCLI, uncomment section (1.0) by deleting hash(#) symbol.

## NOTES:
## For testing, writing and executing script on the VM section has been commented.
## To write scripts uncomment sections (1.6) and (2.9) by deleting hash(#) symbol.
## For simplicity, you may use text editors to write commands and then place it on this script, see section (1.6).

##||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
##Section 1
##PARAMETRES

##(1.0) Importing PowerCLI, See READ_ME section before uncommenting.
#Import-Module VMware.PowerCLI

## (1.1) Login in to server Parametres
$ServerHost = "Your Server Hostname or IP address"
$ServerUserName = "Server Username"
$ServerPassword = "Server Password"

## (1.2) Virtual Switch and Port Groups Parametres
$SwitchName = "Switch Name"
$PortGroupName = "Port Group Name"
$VLANID = "Vlan ID"

## (1.3) VM Parameters
$VM_Name = "VM Name"
$VM_Resource_Pool = "Resource Pool Name"
$DataStore = "Datastore Name"
$VM_Network = "VM Network Name"
$VM_GuestOS = "Guest OS" # Example "Windows_64Guest"
$VM_MemorySize = 0 # Memory size in GB
$Vm_CPU = 0 # Number of CPU cores
$VM_HardDisk = 0 # Hard disk size in GB
$isoPath = "/vmfs/volumes/datastore1/path/to/iso.iso"  # Replace with the actual datastore and ISO path

## (1.4) VM Configuration Parametres
$VM_Username = "VM username"
$VM_Password = "VM Password"
$VM_IP = " VM IP address"
$VM_Subnet = "VM Subnet mask"
$VM_Gateway = "VM Default Gateway"
$VM_DNS = "VM DNS"  #EXAMPLE "192.168.1.1", "!92.168.1.2"
$ssh= $true  #to disable ssh write $false instead of $true

## (1.5) Time to wait in Seconds until VM powers on
$Delay = 60

## (1.6) Creating Script that runs on the VM
# $script = "path to text editor"

##IGNORE BELOW IF USING EXTERNAL APPLICATIONS EX: NOTEPAD OR PWSH SCRIPT EDITOR
## $script = @"
## Write-Host "Starting commands"
## Add your other commands here, ignore if using notepad
## echo 'ls /software/'
## "@

##DO NOT IGNORE BELOW
# $scriptFile = "/vmfs/volumes/datastore_name/YourVMName/my_script.ps1"  # Replace with the actual datastore and path





##||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
## Section 2
## MAIN Methods

## (2.1) Connect to Server
Connect-VIServer -Server $ServerHost -User $ServerUserName -Password $ServerPassword

## (2.2) Create Switch and Port Group
New-VirtualSwitch -Name $SwitchName
New-VirtualPortGroup -VirtualSwitch $SwitchName -Name $PortGroupName -VLanId $VLANID

## (2.3) Create VM
##$vmConfig= New-VM -Name $VM_Name -VMHost $ServerHost -ResourcePool $VM_Resource_Pool -Datastore $DataStore -MemoryGB $VM_MemorySize -NumCpu $Vm_CPU -GuestId $VM_GuestOS
$vmConfig= New-VM -Name $VM_Name -ResourcePool $VM_Resource_Pool -Datastore $DataStore -MemoryGB $VM_MemorySize -NumCpu $Vm_CPU -GuestId $VM_GuestOS
Add-NetworkAdapter -VM $VM_Name -NetworkName $VM_Network
New-HardDisk -VM $VM_Name -CapacityGB $VM_HardDisk -Datastore $DataStore -DiskType Thick
#Set-VM -VM $VM_Name -NumCoresPerSocket 2 -BootOrder "network", "disk"

## (2.4) Add a CD/DVD drive to the VM and mount the ISO
$cdDrive = New-CDDrive -VM $vmConfig
Set-CDDrive -CD $cdDrive -IsoPath $isoPath

## (2.5) Creating VM username,password and enabling SSH
$vm = Get-VM -Name $VM_Name
Set-VMGuestCredential -VM $vm -GuestUser $VM_Username -GuestPassword $VM_Password
if ($ssh){
    try {
        Set-AdvancedSetting -Entity (Get-VM -Name $VM_Name) -Name "tools.settinogs.enableSSH" -Value "true"   
    }
    catch {
        Write-Host "SSH could not be enabled"
    }
    
}

## (2.6) Check if VMware Tools is installed and running
$VM_Tools = $true
if ($vm.ExtensionData.Guest.ToolsStatus -eq "toolsOk") {
    Write-Host "VMware Tools is installed and running on $($VM_Name)."
   
} else {
    Write-Host "VMware Tools is not installed or not running on $($VM_Name)."
    $VM_Tools = $false
}

## (2.7) Configure VM network
$vm = Get-VM -Name $VM_Name
$networkAdapter = Get-NetworkAdapter -VM $vm
$networkAdapter | Set-NetworkAdapter -IP $VM_IP -SubnetMask $VM_Subnet -Gateway $VM_Gateway -DNS $VM_DNS
Start-Sleep -Seconds 10

## (2.8) Power-ON VM
Start-VM -VM $VM_Name
Start-Sleep -Seconds $Delay #Wait for VM to start

## (2.9)  Execute Commands
##Save the Script in its desired path on the ESXI
Set-Content -Path $scriptFile -Value $script -Force
Start-Sleep -Seconds 10
## IF VMware Tools was found will run commands on the VM using built in tools, else will run using ssh.
$Tools_Error = $false
if ($VM_Tools){
    try {
        Invoke-VMScript -VM $vmName -ScriptText $script
    }
    catch {
        Write-Host "Error using built in tools, proceeding to ssh."
        $Tools_Error = $true
    }  
## Runnings commands using ssh.
} else{
    if($ssh -eq $true -or ($ssh -eq $true -and $Tools_Error -eq $true)) 
    {   try {
        $ssh1 = New-SSHSession -ComputerName $VM_Name -Port 22 -Username $VM_Username -Password $VM_Password
        Invoke-SSHCommand -SessionId $ssh1.SessionId -ScriptBlock {
        param($scriptFile)
        powershell -ExecutionPolicy Bypass -File $scriptFile
    } -ArgumentList $scriptFile
    }
    catch {
        Write-Host "Failed to write commands" 
    } }
    else {
        Write-Host "Failed to connect, check if SSH is enabled"
    }
}

## (3.0) Disconnect from server
disconnect-VIServer -Server $ServerHost -Confirm:$false 

##END