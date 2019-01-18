#//////////////////// RECREATE THE VM //////////////////////// 
$rgName = "MGD2UNMGD" 
$subnetName = "default" 
$singleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix 10.0.2.0/24 
$location = "Central US" 
$vnetName = "MGD2UNMGD-vnet" 
$vnet = New-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -Location $location -AddressPrefix 10.0.2.0/24 -Subnet $singleSubnet 
#change the IP
$ipName = "Unmanaged-ip" 
$pip = New-AzureRmPublicIpAddress -Name $ipName -ResourceGroupName $rgName -Location $location -AllocationMethod Dynamic 
#change Nic and give new NIC Name
$nicName = "Unmanaged01" 
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id 

$nsgName = "MGD2UNMGD-nsg" 
$rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rgName -Location $location -Name $nsgName -SecurityRules $rdpRule 

# Define VM 
$vmName = "Unmanaged-VM" 
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize "Standard_D2_v2" 
$vm = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $nic.Id 
$osDiskUri = "https://mgd2unmgddisk.blob.core.windows.net/vhds/mgd2.vhd" 
$osDiskName = $vmName + "osDisk" 
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osDiskUri -CreateOption attach -Windows 
New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vm 

#to stop and update VM
#Stop-AzureRmVM -ResourceGroupName "MGD2UNMGD" -Name "Unmanaged-VM" -force
#update-AzureRMVM -ResourceGroupName "MGD2UNMGD" -Name "Unmanaged-VM" 

