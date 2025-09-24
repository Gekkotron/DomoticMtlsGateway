#!/bin/bash

# DNS Configuration Helper
# This script helps configure DNS resolution for the mTLS gateway

# Detect script location and set proper paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🌐 mTLS Gateway DNS Configuration"
echo "================================="

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    echo "✅ Loaded configuration from .env"
else
    echo "❌ Error: .env file not found!"
    echo "Please run ./scripts/setup.sh first to create the configuration file."
    exit 1
fi

DOMOTIC_HOST=${DOMOTIC_HOST:-domotic.local}
DOMOTIC_PORT=${DOMOTIC_PORT:-443}

echo
echo "📋 Current Configuration:"
echo "   🌐 Gateway Host: $DOMOTIC_HOST"
echo "   🔌 Gateway Port: $DOMOTIC_PORT"
echo "   📍 Full URL: https://$DOMOTIC_HOST:$DOMOTIC_PORT"
echo

# Detect current server IP
if command -v ip &> /dev/null; then
    SERVER_IP=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
elif command -v hostname &> /dev/null; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
else
    SERVER_IP=""
fi

if [ ! -z "$SERVER_IP" ]; then
    echo "🔍 Detected server IP: $SERVER_IP"
else
    echo "❓ Could not auto-detect server IP address."
    echo "   Please find your server's IP address manually."
    echo
    read -p "Enter your server's IP address: " SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        echo "❌ No IP address provided. Exiting."
        exit 1
    fi
fi

echo
echo "🎯 DNS Configuration Required"
echo "============================"
echo "For clients to access the mTLS gateway, they need to resolve"
echo "'$DOMOTIC_HOST' to '$SERVER_IP'"
echo

# Function to show OS-specific instructions
show_client_instructions() {
    local os=$1
    echo "📱 For $os clients:"
    case $os in
        "macOS/Linux")
            echo "   Run this command:"
            echo "   echo '$SERVER_IP $DOMOTIC_HOST' | sudo tee -a /etc/hosts"
            echo
            echo "   Or manually edit /etc/hosts and add:"
            echo "   $SERVER_IP $DOMOTIC_HOST"
            ;;
        "Windows")
            echo "   1. Run Notepad as Administrator"
            echo "   2. Open: C:\\Windows\\System32\\drivers\\etc\\hosts"
            echo "   3. Add this line:"
            echo "      $SERVER_IP $DOMOTIC_HOST"
            echo "   4. Save the file"
            ;;
        "Router/DNS")
            echo "   Add a DNS record in your router or DNS server:"
            echo "   Host: $DOMOTIC_HOST"
            echo "   IP: $SERVER_IP"
            ;;
    esac
    echo
}

echo "Choose your client configuration method:"
echo "1) macOS/Linux clients"
echo "2) Windows clients"
echo "3) Router/DNS server"
echo "4) Show all methods"
echo "5) Test current DNS resolution"
echo

read -p "Select option (1-5): " -n 1 -r
echo
echo

case $REPLY in
    1)
        show_client_instructions "macOS/Linux"
        ;;
    2)
        show_client_instructions "Windows"
        ;;
    3)
        show_client_instructions "Router/DNS"
        ;;
    4)
        show_client_instructions "macOS/Linux"
        show_client_instructions "Windows"
        show_client_instructions "Router/DNS"
        ;;
    5)
        echo "🧪 Testing DNS resolution..."
        if command -v nslookup &> /dev/null; then
            echo "Using nslookup:"
            nslookup $DOMOTIC_HOST || echo "❌ DNS resolution failed"
        elif command -v dig &> /dev/null; then
            echo "Using dig:"
            dig +short $DOMOTIC_HOST || echo "❌ DNS resolution failed"
        else
            echo "Using ping (1 packet):"
            ping -c 1 $DOMOTIC_HOST || echo "❌ DNS resolution or connectivity failed"
        fi
        echo
        echo "If the test failed, DNS configuration is needed on the client."
        ;;
    *)
        echo "Invalid option. Showing all methods:"
        show_client_instructions "macOS/Linux"
        show_client_instructions "Windows"
        show_client_instructions "Router/DNS"
        ;;
esac

echo "💡 Alternative Options:"
echo "========================"
echo "• Use mDNS: Some networks support .local domains automatically"
echo "• Use IP directly: https://$SERVER_IP:$DOMOTIC_PORT (certificate may show warnings)"
echo "• Configure your router's DNS to resolve $DOMOTIC_HOST"
echo

echo "🧪 After configuration, test with:"
echo "   ping $DOMOTIC_HOST"
echo "   ./scripts/test_script.sh"
echo

echo "✅ DNS configuration help completed!"