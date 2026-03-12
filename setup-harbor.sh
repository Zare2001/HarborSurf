#!/bin/bash
# Harbor Setup Script - Downloads and installs Harbor container registry
# Usage: ./setup-harbor.sh [SERVER_IP]
# Example: ./setup-harbor.sh 192.168.1.100
#
# Run on the SERVER where Docker runs (not on Mac without Colima/Docker).
# Do not use 127.0.0.1 or localhost as hostname.

set -e

HARBOR_VERSION="${HARBOR_VERSION:-v2.14.0}"
SERVER_IP="${1:-}"

# Absolute install dir next to this script (avoids cp same-file when harbor.yml is linked into extract tree)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$SCRIPT_DIR/harbor-install}"

echo "=== Harbor Container Registry Setup ==="
echo "Harbor version: $HARBOR_VERSION"
echo "Install dir: $INSTALL_DIR"
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

if [ "$SERVER_IP" = "127.0.0.1" ] || [ "$SERVER_IP" = "localhost" ]; then
    echo "Error: Do not use 127.0.0.1 or localhost. Use the IP/hostname clients use (e.g. 145.38.205.248)."
    exit 1
fi

echo "Using hostname: $SERVER_IP"
echo ""

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

HARBOR_YML="$(pwd)/harbor.yml"

# Copy harbor.yml without triggering "same file" cp error (use cat to always write a new inode)
apply_hostname_sed() {
    local f="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/YOUR_SERVER_IP/$SERVER_IP/g" "$f"
        sed -i '' "s/reg.mydomain.com/$SERVER_IP/g" "$f"
    else
        sed -i "s/YOUR_SERVER_IP/$SERVER_IP/g" "$f"
        sed -i "s/reg.mydomain.com/$SERVER_IP/g" "$f"
    fi
}

if [ -f "$SCRIPT_DIR/harbor.yml" ]; then
    echo "Using harbor.yml from $SCRIPT_DIR"
    cat "$SCRIPT_DIR/harbor.yml" > "$HARBOR_YML"
    apply_hostname_sed "$HARBOR_YML"
    echo "Configured harbor.yml with hostname: $SERVER_IP"
else
    echo "Warning: harbor.yml not found in script directory. Using template (HTTP-only patch)."
    cp harbor.yml.tmpl "$HARBOR_YML"
    apply_hostname_sed "$HARBOR_YML"
    # Prepare fails if https is enabled without certificate paths - force HTTP only
    if grep -q '^https:' "$HARBOR_YML" 2>/dev/null; then
        echo "Stripping active https block for HTTP-only install (avoid ssl_cert error)..."
        # Comment out lines from ^https: through private_key line (template layout)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^https:/,/private_key:/s/^/# /' "$HARBOR_YML"
        else
            sed -i '/^https:/,/private_key:/s/^/# /' "$HARBOR_YML"
        fi
    fi
fi

echo "Running Harbor prepare..."
sudo ./prepare

echo "Installing Harbor..."
sudo ./install.sh

echo ""
echo "=== Harbor installed successfully! ==="
echo "Access Harbor at: http://$SERVER_IP"
echo "Default login: admin / Harbor12345"
echo ""
echo "Image tag format (no http://):"
echo "  $SERVER_IP/<project>/<repo>:<tag>"
echo ""
echo "Docker daemon (server + clients using HTTP): /etc/docker/daemon.json"
echo '  "insecure-registries": ["'"$SERVER_IP"'"]'
echo "Then: sudo systemctl restart docker   (on server)"
echo ""
echo "Colima (Mac): daemon.json is inside the VM; see README push-via-ssh.sh"
echo ""
echo "Push from server after login:"
echo "  docker login $SERVER_IP"
echo "  docker tag myimage $SERVER_IP/myproject/myimage:latest"
echo "  docker push $SERVER_IP/myproject/myimage:latest"
