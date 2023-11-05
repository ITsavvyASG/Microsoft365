import-module C:\GitHub\Microsoft365\Azure\upload-table.ps1 -Force
$mxcheck = Import-Csv C:\GitHub\Microsoft365\ExampleData\MXCheck.csv

upload-table "testTable01" "MXData" $mxcheck

$MXData = get-tableaz "testTable01"

foreach($row in $MXData){
$row.Domain
$row.SPF
}


$MXData | export-csv C:\temp\text.csv -NoTypeInformation