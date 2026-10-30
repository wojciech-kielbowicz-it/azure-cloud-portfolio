New-Item -Path "C:\Operations" -ItemType Directory -Force
New-SmbShare -Name "Operations" -Path "C:\Operations" -ReadAccess "Authenticated Users" -ErrorAction SilentlyContinue
New-Item -Path "C:\Operations\Validation.txt" -ItemType File -Value "Success! SSO works properly" -Force

Import-Module ActiveDirectory
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module AzureADHybridAuthenticationManagement

$EntraDomain = "wojtech-cloud.com"
$ADDomain    = (Get-ADDomain).DNSRoot

Set-AzureADKerberosServer -Domain $ADDomain -UserPrincipalName "bg_adm_01@$EntraDomain"

Get-AzureADKerberosServer -Domain $ADDomain -UserPrincipalName "bg_adm_01@$EntraDomain"