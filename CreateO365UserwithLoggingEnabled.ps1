#Checks to see if we are already connected.
function isMSOLConnected {
    Get-MsolDomain -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}

#first, Connect to exchange online and Office 365
Function connectToMSOL{    
    $UserCredential = Get-Credential
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection -ErrorAction stop
    Import-PSSession $Session
    Connect-MsolService -Credential $UserCredential
    }

if (-not (isMSOLConnected)) {
    ConnectToMSOL
}

#Set License pack options
$Standardlicense = New-MsolLicenseOptions -AccountSkuId "amtci:STANDARDWOFFPACK" -DisabledPlans "YAMMER_ENTERPRISE", "INTUNE_O365", "SWAY", "FLOW_O365_P1", "POWERAPPS_O365_P1", "TEAMS1", "PROJECTWORKMANAGEMENT"
$mailboxcheck=$false
$usercheck=$false
#search for user and assign License pack
while ($usercheck -eq $false){    
    $userupn = read-Host "Enter the UPN of the user you would like to assign licenses"
    try {
    Write-host "Assigning Standard License options to the user " + $userupn
    Set-MsolUserLicense -UserPrincipalName $userupn -AddLicenses "amtci:STANDARDWOFFPACK" -LicenseOptions $Standardlicense -UsageLocation US -ErrorAction Stop
    }
    catch {
    write-host "Error setting user license"
    $error
    }
    if(!$error){
    Write-Host "User license assigned"
    $usercheck=$true
    }
}
#Wait for mailbox creation
"Waiting for mailbox to be created..."
Start-sleep -Seconds 15
while($mailboxcheck -eq $false){
    $error.clear()
    try { 
        Write-host "Checking if mailbox exists..."
        Get-Mailbox -Identity $userupn -ErrorAction stop
        }
    catch { 
        write-host "Error occured, waiting 60 seconds to try again..."
        Start-sleep -seconds 60
        }
    if (!$error) {
        write-host "Mailbox has been configured"
        $mailboxcheck=$true
        }
}
#Enable mailbox auditing
Write-Host "Configuring mailbox auditing..."
Set-Mailbox -Identity $userupn -AuditEnabled $true -AuditLogAgeLimit 180 -AuditAdmin Update, MoveToDeletedItems, SoftDelete, HardDelete, SendAs, SendOnBehalf, Create, UpdateFolderPermission -AuditDelegate Update, SoftDelete, HardDelete, SendAs, Create, UpdateFolderPermissions, MoveToDeletedItems, SendOnBehalf -AuditOwner UpdateFolderPermission, MailboxLogin, Create, SoftDelete, HardDelete, Update, MoveToDeletedItems
Write-Host "Verifying Audit configuration..."
get-mailbox -Identity $userupn | Select Name, AuditEnabled, AuditLogAgeLimit | FL