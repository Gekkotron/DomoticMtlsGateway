#!/bin/bash

# DomoticMtlsGateway Setup Script
# This script initializes the environment and sets up the gateway

set -e

# Detect script location and set proper paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🏠🔐 DomoticMtlsGateway Setup"
echo "================================"

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo "ubuntu"
        elif command -v yum &> /dev/null; then
            echo "rhel"
        elif command -v pacman &> /dev/null; then
            echo "arch"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Function to check and install Caddy
check_install_caddy() {
    if command -v caddy &> /dev/null; then
        echo "✅ Caddy is already installed ($(caddy version | head -n1))"
        return 0
    fi
    
    echo "❌ Caddy is not installed"
    read -p "📦 Do you want to install Caddy now? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "⚠️  Caddy installation skipped. You'll need to install it manually later."
        return 1
    fi
    
    local os=$(detect_os)
    echo "🔧 Installing Caddy for $os..."
    
    case $os in
        "macos")
            if command -v brew &> /dev/null; then
                brew install caddy
            else
                echo "❌ Homebrew not found. Please install Homebrew first:"
                echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                return 1
            fi
            ;;
        "ubuntu")
            sudo apt-get update
            sudo apt-get install -y caddy
            ;;
        "rhel")
            sudo yum install -y caddy || sudo dnf install -y caddy
            ;;
        "arch")
            sudo pacman -S caddy
            ;;
        *)
            echo "❌ Unsupported OS. Please install Caddy manually:"
            echo "   https://caddyserver.com/docs/install"
            return 1
            ;;
    esac
    
    if command -v caddy &> /dev/null; then
        echo "✅ Caddy installed successfully ($(caddy version | head -n1))"
        return 0
    else
        echo "❌ Caddy installation failed"
        return 1
    fi
}

# Check and install Caddy
check_install_caddy

# Check if .env already exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "⚠️  .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# Copy .env.example to .env
if [ ! -f "$PROJECT_ROOT/.env.example" ]; then
    echo "❌ Error: .env.example file not found!"
    exit 1
fi

cp $PROJECT_ROOT/.env.example $PROJECT_ROOT/.env
echo "✅ Created .env file from template"

# Function to prompt for configuration
prompt_config() {
    local var_name=$1
    local description=$2
    local current_value=$3
    local new_value

    echo
    echo "📝 $description"
    echo "Current value: $current_value"
    read -p "Enter new value (press Enter to keep current): " new_value
    
    if [ ! -z "$new_value" ]; then
        # Escape special characters for sed
        escaped_value=$(printf '%s\n' "$new_value" | sed 's/[[\.*^$()+?{|]/\\&/g')
        sed -i.bak "s/^${var_name}=.*/${var_name}=${escaped_value}/" $PROJECT_ROOT/.env
        echo "Updated $var_name to: $new_value"
    fi
}

echo
echo "🔧 Configuration Setup"
echo "======================="
echo "Let's configure your gateway. Press Enter to keep default values."

# Load current values from .env
source $PROJECT_ROOT/.env

# Configure main settings
prompt_config "DOMOTIC_HOST" "Domain name for your gateway" "$DOMOTIC_HOST"

echo
echo "🔌 Port Configuration"
echo "===================="
echo "• Port 443: Standard HTTPS (requires root privileges)"
echo "• Port 8443: Common alternative (no root required)"
echo "• Port 4443: Another alternative (no root required)"
echo "• Other ports >1024: No root privileges required"
prompt_config "DOMOTIC_PORT" "HTTPS port for the gateway" "$DOMOTIC_PORT"
prompt_config "BACKEND_IP" "Hostname or IP of your home automation system" "$BACKEND_IP"
prompt_config "BACKEND_PORT" "Port of your home automation system" "$BACKEND_PORT"

echo
echo "🏢 Certificate Information"
echo "========================="
echo "Configure certificate details (or keep defaults):"

source $PROJECT_ROOT/.env  # Reload updated values
prompt_config "CERT_COUNTRY" "Country code (2 letters)" "$CERT_COUNTRY"
prompt_config "CERT_STATE" "State/Province" "$CERT_STATE"
prompt_config "CERT_CITY" "City" "$CERT_CITY"
prompt_config "CERT_ORG" "Organization name" "$CERT_ORG"

# Clean up backup file
rm -f $PROJECT_ROOT/.env.bak

echo
echo "✅ Configuration completed!"

# Function to configure DNS resolution
configure_dns() {
    echo
    echo "🌐 DNS Configuration"
    echo "==================="
    
    # Reload environment variables
    source $PROJECT_ROOT/.env
    DOMOTIC_HOST=${DOMOTIC_HOST:-domotic.local}
    
    echo "For the mTLS gateway to work, clients need to resolve '$DOMOTIC_HOST'"
    echo "to this server's IP address."
    echo
    
    # Try to detect current IP
    if command -v ip &> /dev/null; then
        SERVER_IP=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    elif command -v hostname &> /dev/null; then
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    else
        SERVER_IP=""
    fi
    
    if [ ! -z "$SERVER_IP" ]; then
        echo "🔍 Detected server IP: $SERVER_IP"
        echo
        echo "📝 To allow client access, add this line to the client's /etc/hosts file:"
        echo "   $SERVER_IP $DOMOTIC_HOST"
        echo
        echo "💡 On macOS/Linux clients, run:"
        echo "   echo '$SERVER_IP $DOMOTIC_HOST' | sudo tee -a /etc/hosts"
        echo
        echo "💡 On Windows clients, add to C:\\Windows\\System32\\drivers\\etc\\hosts:"
        echo "   $SERVER_IP $DOMOTIC_HOST"
    else
        echo "❓ Could not auto-detect server IP address."
        echo "📝 Find your server's IP and add to client's hosts file:"
        echo "   YOUR_SERVER_IP $DOMOTIC_HOST"
    fi
    
    echo
    echo "🔧 Alternative: Use mDNS (if available on your network)"
    echo "   Some networks support .local domains automatically"
    echo "   Test with: ping $DOMOTIC_HOST"
    echo
    
    read -p "📋 Press Enter to continue..." -r
}

# Function to generate Caddyfile from template
generate_caddyfile() {
    echo
    echo "🔧 Generating Caddyfile from template..."
    
    # Reload environment variables to get updated values
    source $PROJECT_ROOT/.env
    
    # Set defaults if not provided
    DOMOTIC_HOST=${DOMOTIC_HOST:-domotic.local}
    DOMOTIC_PORT=${DOMOTIC_PORT:-443}
    BACKEND_IP=${BACKEND_IP:-jeedom.local}
    BACKEND_PORT=${BACKEND_PORT:-80}
    BACKEND_PROTOCOL=${BACKEND_PROTOCOL:-http}
    CERTS_DIR=${CERTS_DIR:-certs}
    LOGS_DIR=${LOGS_DIR:-logs}
    
    # Create logs directory if it doesn't exist
    mkdir -p $PROJECT_ROOT/$LOGS_DIR
    
    # Check if template exists
    if [ ! -f "$PROJECT_ROOT/Caddyfile.template" ]; then
        echo "❌ Error: Caddyfile.template not found!"
        return 1
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
        $PROJECT_ROOT/Caddyfile.template > $PROJECT_ROOT/Caddyfile
    
    echo "✅ Caddyfile generated successfully!"
    echo "🌐 Gateway configured for: https://$DOMOTIC_HOST:$DOMOTIC_PORT"
    echo "🏠 Backend: $BACKEND_PROTOCOL://$BACKEND_IP:$BACKEND_PORT"
    
    # Show special instructions for different ports
    if [ "$DOMOTIC_PORT" = "443" ]; then
        echo "ℹ️  Using standard HTTPS port 443 - may require root privileges"
    elif [ "$DOMOTIC_PORT" -lt 1024 ]; then
        echo "ℹ️  Using privileged port $DOMOTIC_PORT - may require root privileges"
    else
        echo "ℹ️  Using non-privileged port $DOMOTIC_PORT - no root privileges required"
    fi
}

# Configure DNS resolution
configure_dns

# Ask user if they want to generate Caddyfile now
echo
read -p "🔧 Generate Caddyfile from template now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    generate_caddyfile
else
    echo "⏭️  Skipping Caddyfile generation. Run this script again or manually generate it."
fi

echo
echo "📁 Next steps:"
echo "1. Run: ./scripts/generate_certif.sh # Generate certificates"
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "2. Generate Caddyfile (skipped - run this script again)"
else
    echo "2. ✅ Caddyfile generated!"
fi
echo "3. Configure DNS on client machines (see instructions above)"
echo "   Or run: ./scripts/configure_dns.sh # For detailed DNS help"
echo "4. Run: ./scripts/run.sh # Start the gateway"
if [ "$DOMOTIC_PORT" != "443" ]; then
    echo "   Note: Using port $DOMOTIC_PORT (access via https://$DOMOTIC_HOST:$DOMOTIC_PORT)"
    if [ "$DOMOTIC_PORT" -lt "1024" ]; then
        echo "   Privileged port detected - you may need to run with sudo: ./scripts/run.sh --sudo"
    fi
fi
echo "5. Run: ./scripts/test_script.sh  # Test the mTLS setup"
echo
echo "🔍 To modify configuration later, edit the .env file and re-run this script"