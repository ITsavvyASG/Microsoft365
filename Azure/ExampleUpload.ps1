import-module C:\GitHub\Microsoft365\Azure\upload-table.ps1 -Force
$mxcheck = Import-Csv C:\GitHub\Microsoft365\ExampleData\MXCheck.csv

upload-table "testTable01" "MXData" $mxcheck

