Import-Module ActiveDirectory

$domainName = "wojtech-cloud.local"
$upnSuffix  = "wojtech-cloud.com" 
$basePath   = "DC=wojtech-cloud,DC=local"
$password   = ConvertTo-SecureString "!!aaBBdd11!!" -AsPlainText -Force

$currentUpns = (Get-ADForest).UPNSuffixes
if ($currentUpns -notcontains $upnSuffix) {
    Set-ADForest -Identity $domainName -UPNSuffixes @{Add=$upnSuffix}
    Write-Host " -> Suffix: $upnSuffix added to AD DS Forest" -ForegroundColor Green
} else {
    Write-Host " -> Suffix UPN $upnSuffix already exists." -ForegroundColor DarkGray
}

$ouList = @("IT", "HR", "Finance", "Sales", "Marketing", "Operations", "Test")
$allOUs = $ouList + "Groups"

foreach ($ou in $allOUs) {
    $existingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $basePath -ErrorAction SilentlyContinue
    if (-not $existingOU) {
        New-ADOrganizationalUnit -Name $ou -Path $basePath -ProtectedFromAccidentalDeletion:$false
        Write-Host " -> OU: $ou created" -ForegroundColor Green
    } else {
        Write-Host " -> OU $ou already exists." -ForegroundColor DarkGray
    }
}

$firstNames = @(
    "James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph", "Thomas", "Charles", 
    "Christopher", "Daniel", "Matthew", "Anthony", "Mark", "Steven", "Paul", "Andrew", "Joshua", "Kenneth",
    "Mary", "Patricia", "Jennifer", "Linda", "Elizabeth", "Barbara", "Susan", "Jessica"
)

$lastNames = @(
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Wilson", "Anderson", "Taylor", 
    "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White", "Harris", "Clark", "Lewis", 
    "Robinson", "Walker", "Young", "Allen", "King"
)

$allCombinations = @()
foreach ($fn in $firstNames) {
    foreach ($ln in $lastNames) {
        $allCombinations += [PSCustomObject]@{
            Name    = $fn
            Surname = $ln
        }
    }
}

$totalUsers = 100
$selectedPairs = $allCombinations | Get-Random -Count $totalUsers

$users = @()
$usedSamAccounts = @{}

for ($i = 0; $i -lt $totalUsers; $i++) {
    $fName = $selectedPairs[$i].Name
    $lName = $selectedPairs[$i].Surname
    
    $mod = ($i + 1) % 100
    if ($mod -lt 30) { 
        $ou = "Sales"         # 30%
    } elseif ($mod -lt 45) { 
        $ou = "IT"            # 15%
    } elseif ($mod -lt 60) { 
        $ou = "Marketing"     # 15%
    } elseif ($mod -lt 75) { 
        $ou = "Operations"    # 15%
    } elseif ($mod -lt 85) { 
        $ou = "HR"            # 10%
    } elseif ($mod -lt 95) { 
        $ou = "Finance"       # 10%
    } else { 
        $ou = "Test"          # 5%
    }

    $fullBase = "{0}{1}" -f $fName.ToLower(), $lName.ToLower()
    $emailBase = "{0}.{1}" -f $fName.ToLower(), $lName.ToLower()
    $emailAddress = "$emailBase@$upnSuffix"

    if ($fullBase.Length -le 20) {
        $candidateSam = $fullBase
    } else {
        $candidateSam = $fullBase.Substring(0, 20)
    }

    $suffixNum = 1
    while ($usedSamAccounts.ContainsKey($candidateSam)) {
        $numStr = $suffixNum.ToString()
        $maxBaseLen = 20 - $numStr.Length
        $candidateSam = "{0}{1}" -f $fullBase.Substring(0, $maxBaseLen), $numStr
        $suffixNum++
    }
    $usedSamAccounts[$candidateSam] = $true

    $users += [PSCustomObject]@{ 
        Name           = $fName
        Surname        = $lName
        OU             = $ou
        SamAccountName = $candidateSam
        UPN            = $emailAddress
    }
}

$counter = 0
foreach ($u in $users) {
    $givenName      = $u.Name
    $surname        = $u.Surname
    $ou             = $u.OU
    $samAccountName = $u.SamAccountName
    $upn            = $u.UPN
    $path           = "OU=$ou,$basePath"
    $displayName    = "$givenName $surname"

    $existingUser = Get-ADUser -Filter "SamAccountName -eq '$samAccountName' -or UserPrincipalName -eq '$upn'" -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        try {
            New-ADUser -Name $displayName `
                -DisplayName $displayName `
                -GivenName $givenName `
                -Surname $surname `
                -SamAccountName $samAccountName `
                -UserPrincipalName $upn `
                -EmailAddress $upn `
                -Path $path `
                -AccountPassword $password `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -ErrorAction Stop
            
            $counter++
            if ($counter % 25 -eq 0) {
                Write-Host " -> Created $counter / 100 users" -ForegroundColor DarkCyan
            }
        } catch {
            Write-Host " -> Error $displayName ($upn): $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host " -> $displayName ($upn) already exists." -ForegroundColor DarkGray
    }
}

$groupsOuPath = "OU=Groups,$basePath"

foreach ($ou in $ouList) {
    $groupName = "SG-$ou"
    $ouPath    = "OU=$ou,$basePath"

    $existingGroup = Get-ADGroup -Filter "Name -eq '$groupName'" -SearchBase $groupsOuPath -ErrorAction SilentlyContinue

    if (-not $existingGroup) {
        New-ADGroup -Name $groupName `
            -SamAccountName $groupName `
            -GroupCategory Security `
            -GroupScope Global `
            -Path $groupsOuPath
        Write-Host " -> Group: $groupName created" -ForegroundColor Green
    } else {
        Write-Host " -> Group $groupName already exists." -ForegroundColor DarkGray
    }
    
    $ouUsers = Get-ADUser -Filter * -SearchBase $ouPath
    
    if ($ouUsers) {
        Add-ADGroupMember -Identity $groupName -Members $ouUsers -ErrorAction Stop
        Write-Host " -> Added $($ouUsers.Count) users to $groupName" -ForegroundColor Cyan
    }
}

