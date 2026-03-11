#!/bin/bash
# Harbor Setup Script - Downloads and installs Harbor container registry
# Usage: ./setup-harbor.sh [SERVER_IP]
# Example: ./setup-harbor.sh 192.168.1.100

set -e

HARBOR_VERSION="${HARBOR_VERSION:-v2.13.0}"
INSTALL_DIR="${INSTALL_DIR:-./harbor-install}"
SERVER_IP="${1:-}"

echo "=== Harbor Container Registry Setup ==="
echo "Harbor version: $HARBOR_VERSION"
echo ""

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose v2+."
    exit 1
fi

# Get server IP if not provided
if [ -z "$SERVER_IP" ]; then
    echo "Enter your server IP or hostname (for Harbor access):"
    read -r SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        echo "Error: Server IP is required."
        exit 1
    fi
fi

echo "Using hostname: $SERVER_IP"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download Harbor online installer
INSTALLER_URL="https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-online-installer-${HARBOR_VERSION}.tgz"
echo "Downloading Harbor installer..."
if ! curl -fsSL -o "harbor-installer.tgz" "$INSTALLER_URL"; then
    echo "Error: Failed to download Harbor. Check your network and version: $HARBOR_VERSION"
    echo "Available versions: https://github.com/goharbor/harbor/releases"
    exit 1
fi

echo "Extracting..."
tar xzvf harbor-installer.tgz
cd harbor

# Copy and configure harbor.yml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/harbor.yml" ]; then
    cp "$SCRIPT_DIR/harbor.yml" harbor.yml
    # Replace placeholder with actual server IP (macOS/BSD and Linux compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/YOUR_SERVER_IP/$SERVER_IP/g" harbor.yml
    else
        sed -i "s/YOUR_SERVER_IP/$SERVER_IP/g" harbor.yml
    fi
    echo "Configured harbor.yml with hostname: $SERVER_IP"
else
    echo "Warning: harbor.yml not found in script directory. Using default."
    cp harbor.yml.tmpl harbor.yml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/reg.mydomain.com/$SERVER_IP/g" harbor.yml
    else
        sed -i "s/reg.mydomain.com/$SERVER_IP/g" harbor.yml
    fi
fi

# Run prepare (generates docker-compose from harbor.yml)
echo "Running Harbor prepare..."
sudo ./prepare

# Install Harbor (without Trivy for faster install - add --with-trivy for vulnerability scanning)
echo "Installing Harbor..."
sudo ./install.sh

echo ""
echo "=== Harbor installed successfully! ==="
echo "Access Harbor at: http://$SERVER_IP"
echo "Default login: admin / Harbor12345"
echo ""
echo "For HTTP registry, add to Docker daemon (/etc/docker/daemon.json):"
echo '  "insecure-registries": ["'"$SERVER_IP"'"]'
echo "Then restart Docker: systemctl restart docker"
echo ""
echo "Push images:"
echo "  docker login $SERVER_IP"
echo "  docker tag myimage $SERVER_IP/library/myimage"
echo "  docker push $SERVER_IP/library/myimage"
