#!/bin/bash

# Installeer sshpass en python3
sudo apt update -y
sudo apt install -y sshpass
sudo apt install -y python3 

# Maak de nodige directories en files aan
mkdir -p ~/Kismet/custom_plugin
mkdir -p ~/Kismet/logs

cd ~/Kismet/custom_plugin
touch api.py export_logs.sh requirements.txt
sudo chmod +x export_logs.sh # Zorgt er voor dat het bash script uitvoerbaar is

cd /usr/share/kismet/httpd/js/
sudo touch kismet.ui.export.js

cd /usr/share/kismet/httpd/plugins
sudo mkdir -p plugins/export
cd export/
sudo touch manifest.conf


# Vul alle aangemaakte files met de correcte inhoud
cat << 'EOF' > ~/Kismet/custom_plugin/api.py
from fastapi import FastAPI
import uvicorn
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import subprocess
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(BASE_DIR, "export_logs.sh")

app = FastAPI()

# Houdt actieve processen bij a.d.h.v pid. 
processes = {}

# CORS middleware om cross-origin requests te handelen. 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/export")
def start_export():
    """Start export script in achtergrond, return huidige pid."""
    try:
        p = subprocess.Popen(["/bin/bash", SCRIPT])
        pid = p.pid
        processes[pid] = p  # Bijhouden voor latere status checks.
        return {"status": "started", "pid": pid}
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)


@app.get("/export/status")
def export_status(pid: int):
    """Check of export pid nog aan het runnen is."""
    if pid not in processes:
        return {"pid": pid, "running": False}

    p = processes[pid]
    # poll() return None als het nog aan het runnen is, of de code als finished is.
    returncode = p.poll()
    running = returncode is None

    if not running:
        del processes[pid]

    return {"pid": pid, "running": running}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000, log_level="error")
EOF



cat << 'EOF' > ~/Kismet/custom_plugin/export_logs.sh
#!/bin/bash

# SCP based
LOGS_DIR="/home/otis/Kismet/logs" # Log file locatie op de Pi
IP="192.168.137.1"  # IP van het toestel waar de logs naar verstuurd zullen worden
FOLDER="KismetLogs"         # Folder op Windows
USER="kismet"                   # Gebruikersnam van de user 
PASS="kismet"                   # Wachtwoord van de user

LOG_FILE="/tmp/kismet_export.log"

# Bestanden overzetten via Secure Copy (SCP), wachtwoord meegeven via sshpass
sshpass -p "$PASS" scp -r "$LOGS_DIR"/* "$USER@$IP:/Users/$USER/$FOLDER/"

EXIT_CODE=$?
echo "Exit code: $EXIT_CODE" >> "$LOG_FILE"

# Feedback
if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS"
else
    echo "ERROR: Check /tmp/kismet_export.log voor details."
fi
EOF



cat << 'EOF' > ~/Kismet/custom_plugin/requirements.txt
fastapi==0.104.1
uvicorn==0.24.0
EOF



cat << 'EOF' > /usr/share/kismet/httpd/js/kismet.ui.export.js
(function($) {
    var checkInterval = setInterval(function() {
        if (typeof kismet_ui_tabpane !== 'undefined') {
            clearInterval(checkInterval);

            kismet_ui_tabpane.AddTab({
                id: 'export_logs',
                tabTitle: 'Export logs',
                priority: 500,
                createCallback: function(div) {
                    var statusDiv = $('<div>').attr('id','export-status').css('margin-top','10px');
                    var btn = $('<button>')
                        .addClass('btn btn-primary')
                        .text('Export Logs to my device')
                        .on('click', function() {
                            btn.prop('disabled', true).text('Starting...');
                            var host = window.location.hostname;
                            var apiUrl = 'http://' + host + ':5000/export';

                            $.ajax({
                                url: apiUrl,
                                type: 'POST',
                                crossDomain: true,
                                dataType: 'json',
                                success: function(response) {
                                    console.log('Export started:', response);
                                    if (response && response.pid) {
                                        statusDiv.html('Exporting (pid ' + response.pid + ')...');
                                        btn.text('Exporting...');

                                        // Poll until done
                                        var pollExport = function() {
                                            $.ajax({
                                                url: 'http://' + host + ':5000/export/status?pid=' + response.pid,
                                                type: 'GET',
                                                dataType: 'json',
                                                success: function(s) {
                                                    console.log('Status check:', s);
                                                    if (s.running) {
                                                        // Still running, check again in 2 seconds
                                                        setTimeout(pollExport, 2000);
                                                    } else {
                                                        // Done!
                                                        console.log('Export finished!');
                                                        statusDiv.html('<div style="color:green;font-weight:bold;">✓ Export finished!</div>');
                                                        btn.prop('disabled', false).text('Export Logs to Laptop');
                                                    }
                                                },
                                                error: function(xhr, status, error) {
                                                    console.log('Status check error:', status, error, xhr);
                                                    statusDiv.html('<div style="color:red;">Status check failed: ' + error + '</div>');
                                                    btn.prop('disabled', false).text('Export Logs to Laptop');
                                                }
                                            });
                                        };
                                        pollExport();
                                    } else {
                                        alert('Failed to start export');
                                        btn.prop('disabled', false).text('Export Logs to Laptop');
                                    }
                                },
                                error: function(xhr, status, error) {
                                    console.log('Export request error:', status, error);
                                    alert('Export request failed: ' + (error||status) + '\nMake sure the API is running on port 5000');
                                    btn.prop('disabled', false).text('Export Logs to Laptop');
                                }
                            });
                        });

                    div.append(
                        $('<div>').css('padding','20px')
                            .append($('<h3>').text('Export Kismet Logs'))
                            .append($('<p>').css({'color':'#666','font-size':'14px','margin-top':'8px'}).text('Click the button below to export all Kismet log files to your laptop over the network. The export runs in the background and you will be notified when complete.'))
                            .append(btn)
                            .append(statusDiv)
                    );
                }
            });
        }
    }, 100);
})(jQuery);
EOF



cat << 'EOF' > /usr/share/kismet/httpd/plugins/export/manifest.conf
name=Export
description=Export logs button on UI
author=Otis
version=1.0
httpexternal=export.html
EOF

# Installeer de requirements voor de API
pip install -r requirements.txt


