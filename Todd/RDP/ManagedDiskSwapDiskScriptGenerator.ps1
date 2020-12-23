
# $subscriptionID = "<Subscription ID>"
# $rgname = "<Resource Group name>"
# $vmname = "<VM Name>"
# $vhduri = '<VHD URI of the fixed OS disk>'

#$subscriptionID = read-host -prompt "Please enter the subscription ID "
Clear-Host
"This script is used to swap a corrected OS disk with one that is currently attached to a VM"
"Note this app does not RUN the script, it only generates it."
""
$rgname = read-host -prompt "Please enter the resource group name that contains your VM"
$vmname = read-host -prompt "Please enter the VM Name that is getting a fixed disk "
$vhduri = read-host -prompt "Please enter URI of the fixed disk "

clear-host
"Your Script is as follows:"
""
$line1 = "`$rgname` = ""$rgname"""
$line2 = "`$vmname` = ""$vmname"""
$line3 = "`$vhduri` = ""$vhduri"""

write-output $line1
write-output $line2
write-output $line3
write-output '$vm = Get-AzureRMVM -ResourceGroupName $rgname -Name $vmname
$vm.StorageProfile.OsDisk.Vhd.Uri = $vhduri
Update-AzureRmVM -ResourceGroupName $rgname -VM $vm'
""

