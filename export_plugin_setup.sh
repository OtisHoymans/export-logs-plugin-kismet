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

# Base dir variabele dat de locatie opslaagt van dit bestand. 
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Script variabele dat het pad van het script bijhoudt. Dit voorkomt 'File doesn't exist' errors. 
SCRIPT = os.path.join(BASE_DIR, "export_logs.sh")

app = FastAPI()

# Houdt actieve processen bij a.d.h.v process id (pid). 
processes = {}

# CORS middleware om cross-origin requests te handelen. 
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Endpoint dat het ./export_logs.sh script aanroept
@app.post("/export")
def start_export():
    """Start export script, return terwijl de huidige pid."""
    try:
        # Executeer het script in de achtergrond met subprocess.Popen().
        p = subprocess.Popen(["/bin/bash", SCRIPT])
        # Bewaar de huidige process id van het gestarte subprocess. 
        pid = p.pid
        processes[pid] = p  # Bijhouden als dictionary voor latere checks. 
        return {"status": "started", "pid": pid}
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

# Endpoint dat de status van het proces bijhoudt, zo kan er uiteindelijk feedback gegeven worden op de UI als de export voltooid is. 
@app.get("/export/status")
def export_status(pid: int):
    """Kijk na of export pid nog aan het runnen is."""
    if pid not in processes:
        return {"pid": pid, "running": False}

    p = processes[pid]

    # p.poll() kijkt of het subprocess nog bezig is. Als returncode None is, dan is het proces nog bezig (None is None = True). 
    returncode = p.poll()
    running = returncode is None

    # Verwijder het proces uit de dictionary als het niet meer bezig is. 
    if not running:
        del processes[pid]

    return {"pid": pid, "running": running}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000, log_level="error")

EOF



cat << 'EOF' > ~/Kismet/custom_plugin/export_logs.sh
#!/bin/bash

LOGS_DIR="/home/otis/Kismet/logs"
FOLDER="KismetLogs"
# IP=10.42.0.11
# Haal het IP op van het apparaat dat verbonden is met de hotspot van de Pi. Is de Pi verbonden via Ethernet? --> comment de lijn hieronder en vul het IP als statische waarde hierboven in.  
IP=$(ip neigh | awk '$1 ~ /^10\.42\.0\./  {print $1; exit}')
USER="kismet"
PASS="kismet"
LOG_FILE="/tmp/kismet_export.log"

# Logs overzetten via SCP, wachtwoord doogegeven met sshpass
sshpass -p "$PASS" scp -r "$LOGS_DIR"/* "$USER@$IP:/Users/$USER/$FOLDER/"

EXIT_CODE=$?
echo "Exit code: $EXIT_CODE" >> "$LOG_FILE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS"
else
    echo "ERROR: Check /tmp/kismet_export.log for details."
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
                                                        statusDiv.html('<div style="color:lightgreen;font-weight:bold;">✓ Export finished!</div>');
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


