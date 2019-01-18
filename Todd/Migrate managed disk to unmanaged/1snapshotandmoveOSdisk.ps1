 #Variables for snapshot
 $resourceGroupName = 'MGD2UNMGD' 
 $location = 'Central US' 
 $vmName = 'MGD2UNMGD'
   
 
 #Get VN info
 $vm = get-azurermvm -ResourceGroupName $resourceGroupName -Name $vmName
 
 
 #Snapshot info OS Disk
 $snapshotName = 'mgd2unmgdsnapshot'
 $snapshot =  New-AzureRmSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
 #Create snapshot Os Disk
 New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
 
 
 
 ##############################  Copy snapshot to Blob ##########################################
 
 
 #Provide the subscription Id of the subscription where snapshot is created
 $subscriptionId = "5b0df146-f3db-425e-b4e3-100c365ef724"
 
 #Provide the name of your resource group where snapshot is created
 ####$resourceGroupName ="MGD2UNMGD"
 
 #Provide the snapshot name 
 ####$snapshotName = "Test2"
 
 #Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 3600.
 #Know more about SAS here: https://docs.microsoft.com/en-us/azure/storage/storage-dotnet-shared-access-signature-part-1
 $sasExpiryDuration = "3600"
 
 #Provide storage account name where you want to copy the snapshot. 
 $storageAccountName = "mgd2unmgddisk"
 
 #Name of the storage container where the downloaded snapshot will be stored
 $storageContainerName = "vhds"
 
 #Provide the key of the storage account where you want to copy snapshot. 
 $storageAccountKey = 'LhWkohFBlGp9z7CKeh+57KdG5y+owRrrWwOrDJAz5wco3MGoL245cZLFIEotY/RE3ZpxEZNiM4VcOy+yA5K3SA=='
 
 #Provide the name of the VHD file to which snapshot will be copied.
 $destinationVHDFileName = "mgd2datadisk.vhd"
 
 
 # Set the context to the subscription Id where Snapshot is created
 Select-AzureRmSubscription -SubscriptionId $SubscriptionId
 
 #Generate the SAS for the snapshot 
 $sas = Grant-AzureRmSnapshotAccess -ResourceGroupName $ResourceGroupName -SnapshotName $SnapshotName  -DurationInSecond $sasExpiryDuration -Access Read 
  
 #Create the context for the storage account which will be used to copy snapshot to the storage account 
 $destinationContext = New-AzureStorageContext –StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey  
 
 #Copy the snapshot to the storage account 
 $copysnap = Start-AzureStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName
 $copysnap | Get-AzureStorageBlobCopyState 