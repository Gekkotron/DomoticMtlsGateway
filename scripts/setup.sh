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
    mkdir -p ../$LOGS_DIR
    
    # Check if template exists
    if [ ! -f "../Caddyfile.template" ]; then
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
        ../Caddyfile.template > ../Caddyfile
    
    echo "✅ Caddyfile generated successfully!"
    echo "🌐 Gateway configured for: https://$DOMOTIC_HOST:$DOMOTIC_PORT"
    echo "🏠 Backend: $BACKEND_PROTOCOL://$BACKEND_IP:$BACKEND_PORT"
}

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
echo "3. Run: caddy run --config Caddyfile # Start the gateway"
echo "4. Run: ./scripts/test_cert_sni.sh  # Test the setup"
echo
echo "🔍 To modify configuration later, edit the .env file and re-run this script"