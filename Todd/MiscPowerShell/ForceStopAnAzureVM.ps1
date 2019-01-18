#force a VM to stop
Stop-AzureRmVM -ResourceGroupName "yourrgname" -Name "vmname" -force
update-AzureRMVM -resourceGroupName "yourrgname" -VM "vmname"