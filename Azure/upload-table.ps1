﻿#*****************************************************
# This script gets services running on the local machine
# and writes the output to Azure Table Storage
#
#*****************************************************
#Import-Module azure
function Upload-Table {

    param (
        $NameforTable,
        $NameforPartitionKey,
        $Data
    )


    $csvdata = $Data

 



Import-Module az
Import-Module aztable



#Import-Module azurerm
#Import-Module azure
#Import-Module azure.storage
#import-Module AzureRmStorageTable


# Step 1, Set variables
# Enter Table Storage location data 
$storageAccountName = 'rgtd'
$tableName = $NameforTable
$sasToken = '?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupiytfx&se=2060-11-05T10:02:19Z&st=2023-11-05T03:02:19Z&spr=https&sig=AdFl1pw8OninFqrKceNqIOD5YhV%2B1NzsglCg67ZW%2FTg%3D'
$dateTime = get-date
$partitionKey = $NameforPartitionKey
$processes = @()

#$StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $Key
#$Table = (Get-AzStorageTable -Context $StorageContext | where {$_.name -eq "perf"}).CloudTable


# Step 2, Connect to Azure Table Storage
$storageCtx = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
#$tableName = "testTable01"

$table = (Get-AzStorageTable -Name $tableName -Context $storageCtx).CloudTable


#Remove-AzStorageTable -Name $tableName -Context $storageCtx -force
$DeletedTable = Get-AzTableRow `
    -table $table| Remove-AzTableRow -table $table


  #  Get-AzTableRow -table $tablename
  if($table){
  }
  Else{
$CreateTable = New-AzStorageTable -Name $tableName -Context $storageCtx
}

#$CreateTable.Name










# Step 3, get the data 
#$processes = get-process | Sort-Object CPU -descending | select-object -first 10

# Step 4, Write data to Table Storage

  # $azureTable = Get-AzStorageTable -Name $tablename

    foreach ($row in $csvData) {
        $rowData = [ordered]@{
            PartitionKey = $PartitionKey
            RowKey = [guid]::NewGuid().ToString()
        }

        foreach ($column in $csvData[0].PSObject.Properties.Name) {
            $rowData[$column] = $row."$column"
        }

        Add-StorageTableRow -table $table -property $rowData -PartitionKey $partitionKey -rowKey ([guid]::NewGuid().tostring()) | Out-Null
    }


    }



    #upload-table "testTable01" "key" $mxcheck
    #################################################################################################################################