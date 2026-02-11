# Windows PowerShell script setup voor export plugin. 
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
Write-Host "OpenSSH Server configureren"
# Installeer OpenSSH Server als die er niet is
$sshService = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshService.State -ne "Installed") {
    Write-Host "- OpenSSH Server installeren..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

# Start en enable SSH service
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
Write-Host "- SSH service gestart en ingesteld op automatisch starten"

# Configureer firewall regel voor Private profiel
try {
    $existingRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if ($existingRule) {
        Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -Profile Private -Enabled True
        Write-Host "- Bestaande firewall regel bijgewerkt (Private netwerken)"
    } else {
        New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH SSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Private
        Write-Host "- Nieuwe firewall regel aangemaakt (alleen Private netwerken)"
    }
} catch {
    Write-Host "- Firewall regel configuratie: $_"
}

# Zet Pi hotspot netwerk op Private (als verbonden)
Write-Host ""
Write-Host "Netwerk profiel configureren"
try {
    $piConnection = Get-NetConnectionProfile | Where-Object {$_.Name -like "*Pi*" -or $_.Name -like "*Sniffer*"}
    if ($piConnection) {
        Set-NetConnectionProfile -InterfaceIndex $piConnection.InterfaceIndex -NetworkCategory Private
        Write-Host "- Pi hotspot netwerk ingesteld op Private"
    } else {
        Write-Host "- Waarschuwing: Pi hotspot niet gevonden. Zet het netwerk handmatig op Private als je verbindt."
    }
} catch {
    Write-Host "- Netwerk profiel configuratie: $_"
}

Write-Host ""
Write-Host "=== Setup voltooid ==="
Write-Host "Locatie: $dir"
Write-Host "Gebruiker: $username"
Write-Host "Wachtwoord: $password"
Write-Host ""
