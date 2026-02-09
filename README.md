# Kismet Log Exporter

Automates exporting Kismet logs from Linux to Windows over the network using a FastAPI API via added UI functionality on the Kismet web interface. 
<img width="592" height="319" alt="image" src="https://github.com/user-attachments/assets/3573509a-0fbc-4889-a152-bab413f1d825" />
<img width="1089" height="459" alt="image" src="https://github.com/user-attachments/assets/1294a78c-20c6-46fc-8d2b-baaa293c9353" />


> **Note:** Run the Linux setup first, then the Windows setup.

---

## Setup

### Linux (Run First)
```bash
chmod +x setup_linux.sh
./setup_linux.sh
```
After running, change the variables (hostname, ip, ...) to the details of your Windows machine in ~/Kismet/custom_plugin/export_logs.sh.

### Windows
1. Open PowerShell as Administrator.
2. Execute the script (./ExportPluginSetup_kismet.ps1).
