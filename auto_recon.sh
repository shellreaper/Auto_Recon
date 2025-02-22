#!/bin/bash

# Function to display beautiful screens
display_screen() {
    clear
    echo -e "\e[1;34m"
    cat <<"EOF"
 ____  _           _     _     _
|  _ \| |         | |   | |   (_)
| |_) | |_   _ ___| |__ | |__  _ _ __   __ _
|  _ <| | | | / __| '_ \| '_ \| | '_ \ / _` |
| |_) | | |_| \__ \ | | | | | | | | | | (_| |
|____/|_|\__,_|___/_| |_|_| |_|_|_| |_|\__, |
                                        __/ |
                                       |___/
EOF
    echo -e "\n**************************************************"
    echo -e "* $1"
    echo -e "**************************************************\n\e[0m"
}

# Function to handle Ctrl+C signal
ctrl_c() {
    echo -e "\n[*] Do you want to continue with the same tool (c), skip the current tool (s), or quit (q)?"
    read -n 1 choice
    echo
    case $choice in
        c|C)
            ;;
        s|S)
            skip=true
            ;;
        q|Q)
            exit 1
            ;;
        *)
            ctrl_c
            ;;
    esac
}

# Trap Ctrl+C signal
trap ctrl_c SIGINT

# Check if required tools are installed
command -v amass >/dev/null 2>&1 || { echo >&2 "Amass is not installed. Aborting."; exit 1; }
command -v subfinder >/dev/null 2>&1 || { echo >&2 "Subfinder is not installed. Aborting."; exit 1; }
command -v assetfinder >/dev/null 2>&1 || { echo >&2 "Assetfinder is not installed. Aborting."; exit 1; }
command -v naabu >/dev/null 2>&1 || { echo >&2 "Naabu is not installed. Aborting."; exit 1; }
command -v httpx >/dev/null 2>&1 || { echo >&2 "Httpx is not installed. Aborting."; exit 1; }
command -v nuclei >/dev/null 2>&1 || { echo >&2 "Nuclei is not installed. Aborting."; exit 1; }
command -v dnsx >/dev/null 2>&1 || { echo >&2 "Dnsx is not installed. Aborting."; exit 1; }

# Check if domain and output folder provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <output_folder>"
    exit 1
fi

# Set domain and output folder
DOMAIN="$1"
OUTPUT_FOLDER="$2"

# Create output folder if it doesn't exist
mkdir -p "$OUTPUT_FOLDER"

# Reset Ctrl+C flag
skip=false

# Phase 1: Subdomain Enumeration
if [ "$skip" = false ]; then
    display_screen "Subdomain Enumeration"
    echo "[*] Running subdomain enumeration..."

    # Subdomain enumeration with Assetfinder
    echo "[*] Running subdomain enumeration with Assetfinder..."
    assetfinder --subs-only "$DOMAIN" > "$OUTPUT_FOLDER/assetfinder.txt"

    # Running subdomain enumeration with other tools
    echo "[*] Running subdomain enumeration with amass and subfinder..."
    amass enum -d "$DOMAIN" -o "$OUTPUT_FOLDER/amass.txt" -passive -v
    # Filtering Amass results to include only plain subdomains
    awk -F'|' '{print $2}' "$OUTPUT_FOLDER/amass.txt" | grep -Eo '[a-zA-Z0-9._-]+\.'"$DOMAIN" > "$OUTPUT_FOLDER/amass_filtered.txt"
    subfinder -d "$DOMAIN" -o "$OUTPUT_FOLDER/subfinder.txt"

    # Perform DNS bruteforcing with dnsx and Jhaddix wordlist on the root domain
    echo "[*] Performing DNS bruteforcing with dnsx and Jhaddix wordlist on the root domain..."
   # dnsx -d "$DOMAIN" -w /usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt -o "$OUTPUT_FOLDER/dnsx_bruteforce.txt" -r /usr/share/seclists/Miscellaneous/dns-resolvers.txt

    # Combine dnsx results with existing subdomains
    echo "[*] Combining dnsx results with existing subdomains..."
    cat "$OUTPUT_FOLDER/dnsx_bruteforce.txt" >> "$OUTPUT_FOLDER/amass_filtered.txt"
    cat "$OUTPUT_FOLDER/amass_filtered.txt" >> "$OUTPUT_FOLDER/subfinder.txt"
    cat "$OUTPUT_FOLDER/subfinder.txt" >> "$OUTPUT_FOLDER/assetfinder.txt"

    # Filter unique subdomains
    echo "[*] Filtering unique subdomains..."
    sort -u "$OUTPUT_FOLDER/assetfinder.txt" -o "$OUTPUT_FOLDER/subdomains.txt"
fi

# Reset Ctrl+C flag
skip=false

# Phase 2: Port Scanning
if [ "$skip" = false ]; then
    display_screen "Port Scanning"
    echo "[*] Running Naabu for port scanning..."

    # Create a directory to save Naabu output
    mkdir -p "$OUTPUT_FOLDER/naabu"

    # Run Naabu port scanning
    naabu -l "$OUTPUT_FOLDER/subdomains.txt" -o "$OUTPUT_FOLDER/naabu/naabu.txt" --rate 10000 -p 0-65535 -s s
fi

# Reset Ctrl+C flag
skip=false

# Phase 3: HTTP Probing
if [ "$skip" = false ]; then
    display_screen "HTTP Probing"
    echo "[*] Running Httpx for HTTP probing..."
    cat "$OUTPUT_FOLDER/subdomains.txt" | httpx -retries 2 -title -tech-detect -follow-redirects -o "$OUTPUT_FOLDER/httpx.txt"
fi

# Reset Ctrl+C flag
skip=false

# Phase 4: Vulnerability Scanning
if [ "$skip" = false ]; then
    display_screen "Vulnerability Scanning"
    echo "[*] Running Nuclei for vulnerability scanning..."
    nuclei -l "$OUTPUT_FOLDER/subdomains.txt" -t ~/nuclei-templates/ -o "$OUTPUT_FOLDER/nuclei_results.txt" -es info
fi
sudo chown -R `whoami`:`whoami` $OUTPUT_FOLDER/
echo -e "\e[1;32m[*] Recon phase completed.\e[0m"

