#!/bin/bash

# Certificate Sync Script
# Synchronizes certificates from Raspberry Pi to Mac
# Usage: ./sync_certs_from_pi.sh [options]

# Configuration
RASPBERRY_PI_HOST=""
RASPBERRY_PI_USER=""
RASPBERRY_PI_PASSWORD=""  # Leave empty to use SSH key authentication
RASPBERRY_PI_PATH=""
LOCAL_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_CERTS_DIR="$LOCAL_PROJECT_ROOT/certs"
CONFIG_FILE="$LOCAL_PROJECT_ROOT/.sync_config"
LOG_FILE="$LOCAL_PROJECT_ROOT/logs/sync.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create logs directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also display with colors
    case $level in
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log "INFO" "Loaded configuration from $CONFIG_FILE"
    else
        log "WARNING" "Configuration file not found. Will create one."
        return 1
    fi
}

# Function to create configuration file
create_config() {
    log "INFO" "Creating configuration file..."
    
    echo "Please provide the following information for your Raspberry Pi:"
    
    read -p "Raspberry Pi hostname or IP address: " pi_host
    read -p "Username on Raspberry Pi: " pi_user
    read -p "Path to DomoticMtlsGateway on Raspberry Pi (e.g., /home/pi/DomoticMtlsGateway): " pi_path
    
    echo ""
    echo "Authentication method:"
    echo "1. SSH Key (recommended, passwordless)"
    echo "2. Password"
    read -p "Choose authentication method (1 or 2): " auth_method
    
    pi_password=""
    if [ "$auth_method" = "2" ]; then
        read -s -p "Enter Raspberry Pi password: " pi_password
        echo ""
    fi
    
    # Create config file
    cat > "$CONFIG_FILE" << EOF
# Raspberry Pi Sync Configuration
# Generated on $(date)

RASPBERRY_PI_HOST="$pi_host"
RASPBERRY_PI_USER="$pi_user"
RASPBERRY_PI_PASSWORD="$pi_password"
RASPBERRY_PI_PATH="$pi_path"

# SSH Options
SSH_KEY_PATH="\$HOME/.ssh/id_rsa"
SSH_PORT="22"

# Sync Options
SYNC_CERTS=true
SYNC_LOGS=false
BACKUP_BEFORE_SYNC=true
EOF

    log "SUCCESS" "Configuration saved to $CONFIG_FILE"
    
    # Load the new config
    source "$CONFIG_FILE"
}

# Function to test SSH connection
test_ssh_connection() {
    log "INFO" "Testing SSH connection to $RASPBERRY_PI_USER@$RASPBERRY_PI_HOST..."
    
    if [ -n "$RASPBERRY_PI_PASSWORD" ]; then
        # Use password authentication
        log "INFO" "Using password authentication..."
        if command -v sshpass > /dev/null; then
            if sshpass -p "$RASPBERRY_PI_PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "echo 'SSH connection successful'" > /dev/null 2>&1; then
                log "SUCCESS" "SSH connection test passed (password auth)"
                return 0
            else
                log "ERROR" "SSH connection failed with password"
                return 1
            fi
        else
            log "ERROR" "sshpass not found! Install it with: brew install sshpass"
            log "INFO" "Trying without sshpass (you may be prompted for password)..."
            if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "echo 'SSH connection successful'" > /dev/null 2>&1; then
                log "SUCCESS" "SSH connection test passed"
                return 0
            else
                log "ERROR" "SSH connection failed"
                return 1
            fi
        fi
    else
        # Use SSH key authentication
        log "INFO" "Using SSH key authentication..."
        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "echo 'SSH connection successful'" > /dev/null 2>&1; then
            log "SUCCESS" "SSH connection test passed (key auth)"
            return 0
        else
            log "ERROR" "SSH connection failed"
            log "INFO" "Please ensure:"
            log "INFO" "1. SSH key is set up (run: ssh-copy-id $RASPBERRY_PI_USER@$RASPBERRY_PI_HOST)"
            log "INFO" "2. Raspberry Pi is accessible on the network"
            log "INFO" "3. SSH service is running on Raspberry Pi"
            return 1
        fi
    fi
}

# Function to backup existing certificates
backup_local_certs() {
    if [ "$BACKUP_BEFORE_SYNC" = "true" ] && [ -d "$LOCAL_CERTS_DIR" ]; then
        local backup_dir="$LOCAL_PROJECT_ROOT/backups/certs_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r "$LOCAL_CERTS_DIR"/* "$backup_dir/" 2>/dev/null
        log "INFO" "Local certificates backed up to $backup_dir"
    fi
}

# Function to sync certificates
sync_certificates() {
    log "INFO" "Starting certificate synchronization..."
    
    # Create local certs directory if it doesn't exist
    mkdir -p "$LOCAL_CERTS_DIR"
    
    # Backup existing certificates
    backup_local_certs
    
    # Build rsync command
    local rsync_source="$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST:$RASPBERRY_PI_PATH/certs/"
    local rsync_dest="$LOCAL_CERTS_DIR/"
    
    log "INFO" "Syncing from: $rsync_source"
    log "INFO" "Syncing to: $rsync_dest"
    
    # Build SSH command based on authentication method
    local ssh_cmd
    if [ -n "$RASPBERRY_PI_PASSWORD" ]; then
        if command -v sshpass > /dev/null; then
            ssh_cmd="sshpass -p '$RASPBERRY_PI_PASSWORD' ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no"
            log "INFO" "Using password authentication for rsync"
        else
            log "WARNING" "sshpass not found! You may be prompted for password during sync"
            ssh_cmd="ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no"
        fi
    else
        ssh_cmd="ssh -o ConnectTimeout=30"
        log "INFO" "Using SSH key authentication for rsync"
    fi
    
    # Run rsync
    if rsync -avz --delete --progress \
        -e "$ssh_cmd" \
        "$rsync_source" "$rsync_dest" 2>&1 | tee -a "$LOG_FILE"; then
        
        log "SUCCESS" "Certificate synchronization completed"
        
        # List synchronized files
        log "INFO" "Synchronized files:"
        ls -la "$LOCAL_CERTS_DIR" | while read line; do
            log "INFO" "  $line"
        done
        
        return 0
    else
        log "ERROR" "Certificate synchronization failed"
        return 1
    fi
}

# Function to verify synchronized certificates
verify_certificates() {
    log "INFO" "Verifying synchronized certificates..."
    
    local cert_files=("ca_cert.pem" "server_cert.pem" "client_cert.pem" "client_key.pem")
    local missing_files=()
    
    for cert_file in "${cert_files[@]}"; do
        if [ -f "$LOCAL_CERTS_DIR/$cert_file" ]; then
            log "SUCCESS" "Found: $cert_file"
            
            # Verify certificate files (not keys)
            if [[ "$cert_file" == *.pem ]] && [[ "$cert_file" != *key* ]]; then
                if openssl x509 -in "$LOCAL_CERTS_DIR/$cert_file" -noout -text > /dev/null 2>&1; then
                    log "SUCCESS" "$cert_file is valid"
                else
                    log "WARNING" "$cert_file might be corrupted"
                fi
            fi
        else
            missing_files+=("$cert_file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log "SUCCESS" "All certificate files verified"
    else
        log "WARNING" "Missing files: ${missing_files[*]}"
    fi
}

# Function to show usage
show_usage() {
    echo "Certificate Sync Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -c, --config    Reconfigure connection settings"
    echo "  -t, --test      Test SSH connection only"
    echo "  -v, --verify    Verify certificates after sync"
    echo "  -q, --quiet     Quiet mode (less verbose output)"
    echo ""
    echo "Examples:"
    echo "  $0                # Sync certificates"
    echo "  $0 --config      # Reconfigure settings"
    echo "  $0 --test        # Test connection"
}

# Parse command line arguments
QUIET_MODE=false
TEST_ONLY=false
VERIFY_CERTS=true
RECONFIGURE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--config)
            RECONFIGURE=true
            shift
            ;;
        -t|--test)
            TEST_ONLY=true
            shift
            ;;
        -v|--verify)
            VERIFY_CERTS=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log "INFO" "Certificate Sync Script Started"
    log "INFO" "Local project: $LOCAL_PROJECT_ROOT"
    
    # Load or create configuration
    if [ "$RECONFIGURE" = "true" ] || ! load_config; then
        create_config
    fi
    
    # Test SSH connection
    if ! test_ssh_connection; then
        log "ERROR" "Cannot proceed without SSH access"
        exit 1
    fi
    
    if [ "$TEST_ONLY" = "true" ]; then
        log "SUCCESS" "Connection test completed successfully"
        exit 0
    fi
    
    # Sync certificates
    if sync_certificates; then
        if [ "$VERIFY_CERTS" = "true" ]; then
            verify_certificates
        fi
        
        log "SUCCESS" "Certificate sync completed successfully!"
        log "INFO" "You can now test the connection with:"
        log "INFO" "curl --cert certs/client_cert.pem --key certs/client_key.pem --cacert certs/ca_cert.pem https://jeedom.tail497f.ts.net:8443/core/api/jeeApi.php -v"
    else
        log "ERROR" "Certificate sync failed"
        exit 1
    fi
}

# Run main function
main "$@"