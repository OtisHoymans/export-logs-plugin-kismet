# Windows PowerShell script om Kismet SMB share op te zetten. 
# Run als Administrator

$username = "kismet"
$password = "kismet"
$dir = "C:\Users\kismet\KismetLogs"

Write-Host "Lokale gebruiker '$username' aanmaken"
try {
    $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
    New-LocalUser -Name $username -Password $secPassword -FullName "Kismet Export" -Description "Lokale gebruiker voor kismet log export" -PasswordNeverExpires
    Write-Host "- Gebruiker aangemaakt"
} catch {
    Write-Host "De gebruiker bestaat mogelijk al: $_"
}

Write-Host "Folder aanmaken: '$dir'"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "- Folder aangemaakt"
} else {
    Write-Host "- Folder bestaat al"
}

Write-Host "NTFS permissies zetten voor '$username'"
$acl = Get-Acl $dir
$ar = New-Object System.Security.AccessControl.FileSystemAccessRule($username, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($ar)
Set-Acl -Path $dir -AclObject $acl
Write-Host "- NTFS permissies aangemaakt"

Write-Host ""
Write-Host "=== Setup voltooid ==="
Write-Host "Locatie: $dir"
Write-Host "Gebruiker: $username"
Write-Host "Wachtwoord: $password"
Write-Host ""