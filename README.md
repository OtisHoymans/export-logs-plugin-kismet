
# Kismet Log Exporter Plugin

A custom plugin that adds one-click log export functionality to Kismet's web interface, automatically transferring log files from a Raspberry Pi to a connected Windows machine.

## Features

- Adds "Export logs" button to Kismet web interface.
- Automatically transfers `.kismet` log files via SCP.
- Real-time export status feedback.
- Automated setup scripts for both the Linux and Windows side.

## Requirements

- Raspberry Pi running Kismet.
- Windows machine connected to the Pi (via hotspot/ethernet).
- PowerShell with Administrator privileges.
- Network connectivity between devices.

## Setup

### 1. Linux Setup (Run First)
```bash
chmod +x export_plugin_setup.sh
./export_plugin_setup.sh
```

### 2. Windows Setup

1. Open PowerShell as Administrator
2. Check execution policy: `Get-ExecutionPolicy`
3. If needed, set to RemoteSigned: `Set-ExecutionPolicy RemoteSigned`
4. Run the setup script: `./ExportPluginSetup_kismet.ps1`

The script automatically:
- Creates `kismet` user (password: `kismet`).
- Creates export directory: `C:\Users\kismet\KismetLogs`.
- Installs and configures OpenSSH Server.
- Configures Windows Firewall for SCP/SSH access. 

## Usage

1. Start Kismet on the Raspberry Pi.
2. Open Kismet web interface.
3. Click "Export logs" button in the bottom navigation bar.
4. Wait for confirmation message.
5. Access logs at: `C:\Users\kismet\KismetLogs`.

View logs with SQLite tools like DB Browser.

## Cleanup

To remove the kismet user:
```powershell
Remove-LocalUser kismet
Get-LocalUser  # Verify removal
```

Delete the folder: `C:\Users\kismet`