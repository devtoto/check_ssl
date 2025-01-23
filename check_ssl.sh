#!/bin/bash
# SSL Certificate Checker Script
# Reads hosts from hosts.txt, checks SSL certificates,
# generates HTML report and saves certificates
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
echo "Current timezone: ${TZ:-UTC}" >&2
date >&2
OUTPUT_DIR="/var/www/html"
HOSTS_FILE="/app/hosts.txt"

# Konvertiert das SSL-Datum in Sekunden seit Epoch
ssl_date_to_epoch() {
    local ssl_date="$1"
    local month=$(echo "$ssl_date" | awk '{print $1}')
    local day=$(echo "$ssl_date" | awk '{print $2}')
    local time=$(echo "$ssl_date" | awk '{print $3}')
    local year=$(echo "$ssl_date" | awk '{print $4}')
    
    case "$month" in
        Jan) month="01";;
        Feb) month="02";;
        Mar) month="03";;
        Apr) month="04";;
        May) month="05";;
        Jun) month="06";;
        Jul) month="07";;
        Aug) month="08";;
        Sep) month="09";;
        Oct) month="10";;
        Nov) month="11";;
        Dec) month="12";;
    esac
    
    date -d "$year-$month-$day $time" +%s
}

process_hosts() {
    local tmpfile=$(mktemp)
    local host_count=0
    local processed_count=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Clean and validate line
        line=$(echo "$line" | tr -d '\r' | xargs | grep -Ev '^#')
        [ -z "$line" ] && continue

        # Extract host and port with validation
        host=$(echo "$line" | awk '{print $1}' | tr -d '\r')
        port=$(echo "$line" | awk '{print $2}' | tr -d '\r' | grep -Eo '^[0-9]+$')
        
        # Validate both values exist
        if [ -z "$host" ] || [ -z "$port" ]; then
            continue
        fi
        
        host_count=$((host_count + 1))
        
        # Try with SNI first
        cert_info=$(timeout 30 openssl s_client -connect "$host:$port" -servername "$host" 2>/dev/null </dev/null)
        if [ $? -ne 0 ]; then
            # If SNI fails, try without SNI
            cert_info=$(timeout 30 openssl s_client -connect "$host:$port" 2>/dev/null </dev/null)
        fi
        
        cert_dates=$(echo "$cert_info" | openssl x509 -noout -dates 2>/dev/null)
        
        if [ -z "$cert_dates" ]; then
            echo "<tr><td>$host</td><td>$port</td><td colspan=\"2\" style=\"color: #e74c3c;\">Fehler: Verbindung fehlgeschlagen oder kein Zertifikat gefunden</td></tr>" >> "$tmpfile"
            continue
        fi

        processed_count=$((processed_count + 1))

        expiry_date=$(echo "$cert_dates" | grep 'notAfter=' | cut -d= -f2)
        expiry_epoch=$(ssl_date_to_epoch "$expiry_date")
        now_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

        if [ "$days_left" -lt 7 ]; then
            days_class="days-critical"
        elif [ "$days_left" -lt 30 ]; then
            days_class="days-warning"
        else
            days_class="days-ok"
        fi

        formatted_date=$(TZ=${TZ:-UTC} date -d "@$expiry_epoch" '+%d.%m.%Y %H:%M')
        # Save certificate and CSR to files
        mkdir -p "${OUTPUT_DIR}/certs"
        
        # Save certificate
        cert_file="${OUTPUT_DIR}/certs/${host}.crt"
        echo "$cert_info" | openssl x509 -out "$cert_file"
        
        echo "<tr><td>$host</td><td>$port</td><td class=\"days-remaining ${days_class}\">$days_left</td><td>$formatted_date</td><td><a href=\"certs/${host}.crt\" download>Download CRT</a></td></tr>" >> "$tmpfile"
    done < "$HOSTS_FILE"
    
    cat "$tmpfile"
    rm "$tmpfile"
}

generate_report() {
    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SSL Certificate Status</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 20px auto;
            padding: 0 20px;
            background-color: #f5f5f5;
        }
        h1 {
            color: #2c3e50;
            text-align: center;
            padding: 20px 0;
            border-bottom: 2px solid #3498db;
        }
        .timestamp {
            text-align: center;
            color: #7f8c8d;
            margin-bottom: 30px;
        }
        .refresh-button {
            display: block;
            width: 200px;
            margin: 20px auto;
            padding: 10px;
            background-color: #3498db;
            color: white;
            text-align: center;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
        }
        .refresh-button:hover {
            background-color: #2980b9;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background-color: white;
            box-shadow: 0 1px 3px rgba(0,0,0,0.2);
            border-radius: 8px;
            overflow: hidden;
            margin-top: 20px;
        }
        th {
            background-color: #3498db;
            color: white;
            padding: 15px;
            text-align: left;
        }
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #ddd;
        }
        tr:last-child td {
            border-bottom: none;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        .days-remaining {
            font-weight: bold;
        }
        .days-critical {
            color: #e74c3c;
        }
        .days-warning {
            color: #f39c12;
        }
        .days-ok {
            color: #27ae60;
        }
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 30px;
            height: 30px;
            animation: spin 1s linear infinite;
            margin: 0 auto 10px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
    <script>
        function showLoading() {
            document.getElementById('loading').style.display = 'block';
        }
    </script>
</head>
<body>
    <h1>SSL Certificate Status</h1>
    <p class="timestamp">"Zuletzt aktualisiert: $(TZ=${TZ:-UTC} date +'%d.%m.%Y %H:%M:%S')"</p>
    <script>
        function updateTimestamp() {
            const timestampElement = document.querySelector('.timestamp');
            if (timestampElement) {
                const now = new Date();
                const formattedDate = now.toLocaleString('de-DE', {
                    day: '2-digit',
                    month: '2-digit',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit'
                });
                timestampElement.textContent = "Zuletzt aktualisiert: " + formattedDate;
            }
        }
        window.addEventListener('load', updateTimestamp);
    </script>
    <table>
        <tr>
            <th>Host</th>
            <th>Port</th>
            <th>Tage bis Ablauf</th>
            <th>Ablaufdatum</th>
            <th>Zertifikat</th>
        </tr>
EOF

    if [ ! -f "$HOSTS_FILE" ]; then
        echo "<tr><td colspan=\"4\" style=\"color: #e74c3c;\">Hosts-Datei nicht gefunden: $HOSTS_FILE</td></tr>"
    else
        process_hosts
    fi

    cat << EOF
    </table>
</body>
</html>
EOF
}

mkdir -p "$OUTPUT_DIR"
generate_report > "$OUTPUT_DIR/index.html"

if [ "$REQUEST_URI" = "/check" ]; then
    echo "Status: 302 Found"
    echo "Location: /"
    echo
fi
