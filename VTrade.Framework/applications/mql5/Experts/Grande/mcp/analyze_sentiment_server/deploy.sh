#!/bin/bash
# Grande Sentiment MCP Server Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="grande-sentiment"
INSTALL_DIR="/opt/grande-sentiment"
SERVICE_USER="mcpuser"

echo -e "${GREEN}Grande Sentiment MCP Server Deployment${NC}"
echo "========================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root${NC}"
   exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo "Checking dependencies..."
if ! command_exists python3; then
    echo -e "${RED}Python 3 is required but not installed${NC}"
    exit 1
fi

if ! command_exists pip3; then
    echo -e "${RED}pip3 is required but not installed${NC}"
    exit 1
fi

if ! command_exists curl; then
    echo -e "${RED}curl is required but not installed${NC}"
    exit 1
fi

echo -e "${GREEN}All dependencies found${NC}"

# Create service user
echo "Creating service user..."
if ! id "$SERVICE_USER" &>/dev/null; then
    sudo useradd -r -s /bin/false -d "$INSTALL_DIR" "$SERVICE_USER"
    echo -e "${GREEN}Service user created${NC}"
else
    echo -e "${YELLOW}Service user already exists${NC}"
fi

# Create installation directory
echo "Setting up installation directory..."
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

# Copy files
echo "Copying application files..."
cp main.py requirements.txt monitor.py "$INSTALL_DIR/"
sudo chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"/*

# Create virtual environment
echo "Setting up Python virtual environment..."
cd "$INSTALL_DIR"
sudo -u "$SERVICE_USER" python3 -m venv .venv
sudo -u "$SERVICE_USER" .venv/bin/pip install --upgrade pip
sudo -u "$SERVICE_USER" .venv/bin/pip install -r requirements.txt
sudo -u "$SERVICE_USER" .venv/bin/pip install requests  # For monitor script

# Install systemd service
echo "Installing systemd service..."
sudo cp grande-sentiment.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

# Create log directory
sudo mkdir -p /var/log/grande-sentiment
sudo chown "$SERVICE_USER:$SERVICE_USER" /var/log/grande-sentiment

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "To start the service:"
echo "  sudo systemctl start $SERVICE_NAME"
echo ""
echo "To check status:"
echo "  sudo systemctl status $SERVICE_NAME"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "To start monitoring:"
echo "  cd $INSTALL_DIR && python3 monitor.py"
