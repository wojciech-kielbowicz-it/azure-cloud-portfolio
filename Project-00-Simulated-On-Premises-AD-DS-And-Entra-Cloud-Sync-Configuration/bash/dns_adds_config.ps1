# Requires -RunAsAdministrator

Import-Module ServerManager

Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

$password = ConvertTo-SecureString "!!aaBBdd11!!" -AsPlainText -Force

Install-ADDSForest -CreateDnsDelegation:$false `
    -DomainMode "WinThreshold" `
    -DomainName "wojtech-cloud.local" `
    -DomainNetbiosName "WOJTECH-CLOUD" `
    -ForestMode "WinThreshold" `
    -SafeModeAdministratorPassword $password `
    -Force
