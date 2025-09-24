#!/bin/bash

# Update Caddyfile from template and environment variables
# This script reads the .env file and regenerates the Caddyfile

# Detect script location and set proper paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔄 Updating Caddyfile from template..."
echo "===================================="

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    echo "✅ Loaded configuration from .env"
else
    echo "❌ Error: .env file not found!"
    echo "Please run ./scripts/setup.sh first to create the configuration file."
    exit 1
fi

# Set defaults if not provided
DOMOTIC_HOST=${DOMOTIC_HOST:-domotic.local}
DOMOTIC_PORT=${DOMOTIC_PORT:-443}
BACKEND_IP=${BACKEND_IP:-jeedom.local}
BACKEND_PORT=${BACKEND_PORT:-80}
BACKEND_PROTOCOL=${BACKEND_PROTOCOL:-http}
CERTS_DIR=${CERTS_DIR:-certs}
LOGS_DIR=${LOGS_DIR:-logs}

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/$LOGS_DIR"

# Check if template exists
if [ ! -f "$PROJECT_ROOT/Caddyfile.template" ]; then
    echo "❌ Error: Caddyfile.template not found!"
    exit 1
fi

# Backup existing Caddyfile if it exists
if [ -f "$PROJECT_ROOT/Caddyfile" ]; then
    cp "$PROJECT_ROOT/Caddyfile" "$PROJECT_ROOT/Caddyfile.backup"
    echo "📄 Backed up existing Caddyfile to Caddyfile.backup"
fi

# Replace template variables
sed \
    -e "s|{{DOMOTIC_HOST}}|$DOMOTIC_HOST|g" \
    -e "s|{{DOMOTIC_PORT}}|$DOMOTIC_PORT|g" \
    -e "s|{{BACKEND_IP}}|$BACKEND_IP|g" \
    -e "s|{{BACKEND_PORT}}|$BACKEND_PORT|g" \
    -e "s|{{BACKEND_PROTOCOL}}|$BACKEND_PROTOCOL|g" \
    -e "s|{{CERTS_DIR}}|$CERTS_DIR|g" \
    -e "s|{{LOGS_DIR}}|$LOGS_DIR|g" \
    "$PROJECT_ROOT/Caddyfile.template" > "$PROJECT_ROOT/Caddyfile"

echo "✅ Caddyfile updated successfully!"
echo ""
echo "📋 Current configuration:"
echo "   🌐 Gateway: https://$DOMOTIC_HOST:$DOMOTIC_PORT"
echo "   🏠 Backend: $BACKEND_PROTOCOL://$BACKEND_IP:$BACKEND_PORT"
echo "   📁 Certificates: $CERTS_DIR/"
echo "   📝 Logs: $LOGS_DIR/"
echo ""

# Show special instructions for different ports
if [ "$DOMOTIC_PORT" = "443" ]; then
    echo "ℹ️  Using standard HTTPS port 443"
    echo "   Start with: ./scripts/run.sh (may require sudo)"
elif [ "$DOMOTIC_PORT" -lt 1024 ]; then
    echo "ℹ️  Using privileged port $DOMOTIC_PORT"
    echo "   Start with: ./scripts/run.sh (may require sudo)"
else
    echo "ℹ️  Using non-privileged port $DOMOTIC_PORT"
    echo "   Start with: ./scripts/run.sh"
fi

echo ""
echo "🚀 Ready to start: ./scripts/run.sh"