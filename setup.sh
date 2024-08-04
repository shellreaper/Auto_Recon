#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Update package list and install dependencies
sudo apt update
sudo apt install -y wget git curl snapd

# Install Go if not already installed
if ! command_exists go; then
    echo "Installing Go..."
    wget https://dl.google.com/go/go1.20.4.linux-amd64.tar.gz
    sudo tar -xvf go1.20.4.linux-amd64.tar.gz
    sudo mv go /usr/local
    rm go1.20.4.linux-amd64.tar.gz
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
    source ~/.profile
else
    echo "Go is already installed."
fi

# Set Go environment variables
echo "Setting up Go environment..."
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
echo "export GOPATH=$HOME/go" >> ~/.profile
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile
source ~/.profile

# Install Go-based tools
install_go_tool() {
    if ! command_exists "$1"; then
        echo "Installing $1..."
        go install "$2"
        sudo ln -sf "$GOPATH/bin/$1" "/usr/local/bin/$1"
    else
        echo "$1 is already installed."
    fi
}

install_go_tool amass github.com/owasp-amass/amass/v4/...@master
install_go_tool subfinder github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
install_go_tool naabu github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
install_go_tool dnsx github.com/projectdiscovery/dnsx/cmd/dnsx@latest
install_go_tool nuclei github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
install_go_tool httpx github.com/projectdiscovery/httpx/cmd/httpx@latest
install_go_tool assetfinder github.com/tomnomnom/assetfinder@latest

# Verify installation
echo "Verifying installation..."
for tool in amass subfinder naabu assetfinder dnsx nuclei httpx; do
    if command_exists $tool; then
        echo "$tool installed successfully"
    else
        echo "Failed to install $tool"
    fi
done

echo "Installation completed."

echo "Installation completed."
