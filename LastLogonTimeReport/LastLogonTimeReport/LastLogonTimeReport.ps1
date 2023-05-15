<#
=============================================================================================
Name:           Export Microsoft 365 users' last logon time report using PowerShell
Version: 4.0
Last updated on: May, 2023
website:        o365reports.com
For detailed Script execution:  https://o365reports.com/2019/03/07/export-office-365-users-last-logon-time-csv/
============================================================================================
#>
Param
(
    [string]$MBNamesFile,
    [int]$InactiveDays,
    [switch]$UserMailboxOnly,
    [switch]$ReturnNeverLoggedInMB,
    [switch]$SigninAllowedUsersOnly,
    [switch]$LicensedUsersOnly,
    [switch]$AdminsOnly,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)
Function ConnectModules 
{
    $MsGraphModule =  Get-Module Microsoft.Graph -ListAvailable
    if($MsGraphModule -eq $null)
    { 
        Write-host "Important: Microsoft Graph Powershell module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Microsoft Graph Powershell module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph Powershell module..."
            Install-Module -Name Microsoft.Graph -Scope CurrentUser
            Write-host "Microsoft Graph Powershell module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Microsoft Graph Powershell module must be available in your system to run the script" -ForegroundColor Red
            Exit 
        } 
    }
    else
    {
        [Version]$InstalledVersion = (Get-InstalledModule Microsoft.Graph).Version
        $Result = $InstalledVersion.CompareTo([Version]"1.10.0")
        if($Result -eq -1)
        {
            $Confirm = Read-Host "The installed version of the Microsoft Graph Powershell module is not supported. Do you want to update the module? [Y] Yes [N] No"
            if($confirm -match "[yY]") 
            { 
                Update-Module -Name Microsoft.Graph
            } 
            else
            { 
                Exit 
            }
        }
    }
    $ExchangeOnlineModule =  Get-Module ExchangeOnlineManagement -ListAvailable
    if($ExchangeOnlineModule -eq $null)
    { 
        Write-host "Important: Exchange Online module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Exchange Online module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Exchange Online module..."
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
            Write-host "Exchange Online Module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Exchange Online module must be available in your system to run the script" 
            Exit 
        } 
    }
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
    Write-Progress -Activity "Connecting modules(Microsoft Graph and Exchange Online module)..."
    try{
        if($TenantId -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
        {
            Connect-MgGraph  -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError|Out-Null
            if($ConnectionError -ne $null)
            {    
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
            $Scopes = (Get-MgContext).Scopes
            if($Scopes -notcontains "Directory.Read.All" -and $Scopes -notcontains "Directory.ReadWrite.All")
            {
                Write-Host "Note: Your application required the following graph application permissions: Directory.Read.All" -ForegroundColor Yellow
                Exit
            }
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization (Get-MgDomain | Where-Object {$_.isInitial}).Id -ShowBanner:$false
        }
        else
        {
            Connect-MgGraph -Scopes "Directory.Read.All"  -ErrorAction SilentlyContinue -Errorvariable ConnectionError |Out-Null
            if($ConnectionError -ne $null)
            {
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
            Connect-ExchangeOnline -UserPrincipalName (Get-MgContext).Account -ShowBanner:$false
        }
    }
    catch
    {
        Write-Host $_.Exception.message -ForegroundColor Red
        Exit
    }
    Write-Host "Microsoft Graph Powershell module is connected successfully" -ForegroundColor Yellow
    Write-Host "Exchange Online module is connected successfully" -ForegroundColor Yellow
}
Function CloseConnection
{
    Disconnect-MgGraph|Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
}
Function ProcessMailBox
{
    Write-Progress -Activity "`n     Processing mailbox: $Script:MailBoxUserCount - $DisplayName"
    $Script:MailBoxUserCount++
    if($AccountEnabled -eq $True)
    {
        $SigninStatus = "Allowed"
    }
    else
    {
        $SigninStatus = "Blocked"
    }

    #Retrieve lastlogon time and then calculate Inactive days
    if($LastLogonTime -eq $null)
    {
        $LastLogonTime = "Never Logged In"
        $InactiveDaysOfUser = "-"
    }
    else
    {
        $InactiveDaysOfUser = (New-TimeSpan -Start $LastLogonTime).Days
    }

    #Get licenses assigned to mailboxes
    $Licenses = (Get-MgUserLicenseDetail -UserId $UPN).SkuPartNumber
    $AssignedLicense = @()
    #Convert license plan to friendly name
    if($Licenses.count -eq 0)
    {
        $AssignedLicense = "No License Assigned"
    }
    else
    {
        foreach($License in $Licenses)
        {
            $EasyName = $FriendlyNameHash[$License]
            if(!($EasyName))
            {$NamePrint = $License}
            else
            {$NamePrint = $EasyName}
            $AssignedLicense += $NamePrint
        }
    }
    #Inactive days based filter
    if($InactiveDaysOfUser -ne "-")
    {
        if(($InactiveDays -ne "") -and ($InactiveDays -gt $InactiveDaysOfUser))
        {
            return
        }
    }
    #UserMailboxOnly
    if(($UserMailboxOnly.IsPresent) -and ($MailBoxType -ne "UserMailbox"))
    {
        return
    }
    #Never Logged In user
    if(($ReturnNeverLoggedInMB.IsPresent) -and ($LastLogonTime -ne "Never Logged In"))
    {
        return
    }
    #Signin Allowed Users
    if($SigninAllowedUsersOnly.IsPresent -and $AccountEnabled -eq $False)
    {
        
        return
    }
    #Licensed Users ony
    if($LicensedUsersOnly -and $Licenses.Count -eq 0)
    {
        return
    }
    #Get roles assigned to user
    $Roles = @()
    $params = @{SecurityEnabledOnly = $true}
    try {
        $ObjectIds = Get-MgDirectoryObjectMemberObject -DirectoryObjectId $DirectoryObjectId -BodyParameter $params
    }
    catch
    {
    }
    Foreach($ObjectId in $ObjectIds)
    {
        $MembershipIds = Get-MgDirectoryObject -DirectoryObjectId $ObjectId 
        if($MembershipIds.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.directoryRole")
        {
            $Roles += $MembershipIds.AdditionalProperties.displayName
        }
    }
    if($Roles.count -eq 0) 
    { 
        $RolesAssigned = "No roles" 
    } 
    else 
    { 
        $RolesAssigned = @($Roles) -join ',' 
    } 
    #Admins only
    if($AdminsOnly.IsPresent -and $RolesAssigned -eq 'No roles')
    {
        return
    }
    #Export result to CSV file
    $Script:OutputCount++
    $Result = [PSCustomObject]@{'UserPrincipalName'=$UPN;'DisplayName'=$DisplayName;'SigninStatus' = $SigninStatus ;'LastLogonTime'=$LastLogonTime;'CreationTime'=$_.WhenCreated;'InactiveDays'=$InactiveDaysOfUser;'MailboxType'=$MailBoxType; 'AssignedLicenses'=(@($AssignedLicense)-join ',');'Roles'=$RolesAssigned}
    $Result | Export-Csv -Path $ExportCSV -Notype -Append
}

#Get friendly name of license plan from external file
try{
    $FriendlyNameHash = Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction SilentlyContinue -ErrorVariable FileError | ConvertFrom-StringData
    if($FileError -ne $null)
    {
        Write-Host $FileError -ForegroundColor Red
        Exit
    }
}
catch
{
    Write-Host $_.Exception.Message -ForegroundColor Red
    Exit
}
#Module functions
ConnectModules
Select-MgProfile -Name beta
#Set output file
$ExportCSV = ".\LastLogonTimeReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$MailBoxUserCount = 1
$OutputCount = 0

#Check for input file
if([string]$MBNamesFile -ne "") 
{ 
    #We have an input file, read it into memory 
    $Mailboxes = @()
    try{
        $InputFile = Import-Csv -Path $MBNamesFile -Header "MBIdentity"
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        CloseConnection
        Exit
    }
    Foreach($item in $InputFile.MBIdentity)
    {
        $Mailbox = Get-ExoMailBox -Identity $item -PropertySets All -ErrorAction SilentlyContinue
        if($Mailbox -ne $null)
        {
            $DisplayName = $Mailbox.DisplayName
            $UPN = $Mailbox.UserPrincipalName
            $LastLogonTime = (Get-ExoMailboxStatistics -Identity $UPN -Properties LastLogonTime).LastLogonTime
            $MailBoxType = $Mailbox.RecipientTypeDetails
            $DirectoryObjectId = $Mailbox.ExternalDirectoryObjectId
            $CreatedDateTime = $Mailbox.WhenCreated
            $AccountEnabled = (Get-MgUser -UserId $UPN).AccountEnabled
            ProcessMailBox
        } 
        else
        {
            Write-Host $item not found -ForegroundColor Red
        }   
    }
}

#Get all mailboxes from Office 365
else
{
    Get-ExoMailbox -ResultSize Unlimited -PropertySets All | Where{$_.DisplayName -notlike "Discovery Search Mailbox"} | ForEach-Object {
        $DisplayName = $_.DisplayName
        $UPN = $_.UserPrincipalName
        $LastLogonTime = (Get-ExoMailboxStatistics -Identity $UPN -Properties LastLogonTime).LastLogonTime
        $MailBoxType = $_.RecipientTypeDetails
        $DirectoryObjectId = $_.ExternalDirectoryObjectId
        $CreatedDateTime = $_.WhenCreated
        $AccountEnabled = (Get-MgUser -UserId $UPN).AccountEnabled
        ProcessMailBox
    }
}
#Open output file after execution
Write-Host `nScript executed successfully
if((Test-Path -Path $ExportCSV) -eq "True")
{
    Write-Host `n~~ Check out """AdminDroid Office 365 Reports""" to get access to 1800+ Microsoft 365 reports. ~~`n -ForegroundColor Green
    Write-Host "Exported report has $OutputCount mailboxe(s)" 
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open output file?",` 0,"Open Output File",4)
    if ($UserInput -eq 6)
    {
        Invoke-Item "$ExportCSV"
    }
    Write-Host "Detailed report available in: $ExportCSV"
}
else
{
    Write-Host "No mailbox found" -ForegroundColor Red
}
CloseConnection