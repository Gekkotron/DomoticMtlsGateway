#!/bin/bash

# DomoticMtlsGateway Run Script
# This script starts Caddy with the configured Caddyfile

set -e

# Detect script location and set proper paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CADDYFILE="$PROJECT_ROOT/Caddyfile"
LOGS_DIR="$PROJECT_ROOT/logs"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    DOMOTIC_PORT=${DOMOTIC_PORT:-443}
    DOMOTIC_HOST=${DOMOTIC_HOST:-domotic.local}
else
    echo "⚠️  Warning: .env file not found. Using defaults."
    DOMOTIC_PORT=443
    DOMOTIC_HOST="domotic.local"
fi

echo "🏠🔐 DomoticMtlsGateway - Starting Caddy"
echo "========================================"

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
    echo "❌ Error: Caddy is not installed or not in PATH"
    echo "Please install Caddy first or run the setup script:"
    echo "  ./scripts/setup.sh"
    exit 1
fi

# Check if Caddyfile exists
if [[ ! -f "$CADDYFILE" ]]; then
    echo "❌ Error: Caddyfile not found at $CADDYFILE"
    exit 1
fi

# Create logs directory if it doesn't exist
if [[ ! -d "$LOGS_DIR" ]]; then
    echo "📁 Creating logs directory..."
    mkdir -p "$LOGS_DIR"
fi

# Check if certificates exist
CERT_DIR="$PROJECT_ROOT/certs"
if [[ ! -f "$CERT_DIR/server_cert.pem" ]] || [[ ! -f "$CERT_DIR/server_key.pem" ]] || [[ ! -f "$CERT_DIR/ca_cert.pem" ]]; then
    echo "⚠️  Warning: SSL certificates not found in $CERT_DIR"
    echo "Please generate certificates first:"
    echo "  ./scripts/generate_certif.sh"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo "📂 Project root: $PROJECT_ROOT"
echo "📄 Using Caddyfile: $CADDYFILE"
echo "📁 Logs directory: $LOGS_DIR"
echo "🌐 Gateway URL: https://$DOMOTIC_HOST:$DOMOTIC_PORT"

# Check if port requires privileges
REQUIRES_SUDO=false
if [ "$DOMOTIC_PORT" -lt 1024 ] && [ "$DOMOTIC_PORT" != "443" ] || [ "$DOMOTIC_PORT" = "443" ]; then
    if [ "$DOMOTIC_PORT" = "443" ] || [ "$DOMOTIC_PORT" = "80" ]; then
        echo "🔐 Port $DOMOTIC_PORT requires root privileges"
        REQUIRES_SUDO=true
    fi
fi

echo ""

# Change to project root directory
cd "$PROJECT_ROOT"

echo "🚀 Starting Caddy server..."
echo "Press Ctrl+C to stop the server"
echo ""

# Run Caddy with the Caddyfile
# --config specifies the Caddyfile location
# --adapter specifies we're using the Caddyfile format (not JSON)
if [ "$REQUIRES_SUDO" = true ]; then
    echo "⚠️  Running with sudo for privileged port $DOMOTIC_PORT"
    exec sudo caddy run --config "$CADDYFILE" --adapter caddyfile
else
    exec caddy run --config "$CADDYFILE" --adapter caddyfile
fi