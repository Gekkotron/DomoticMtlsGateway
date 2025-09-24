#!/bin/bash

# Detect script location and set proper paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}❌ Error: .env file not found!${NC}"
    echo "Please run ./scripts/setup.sh first to create the configuration file."
    exit 1
fi

# Configuration from .env with defaults
DOMAIN="${DOMOTIC_HOST}:${DOMOTIC_PORT:-443}"
API_ENDPOINT="/core/api/jeeApi.php"
CERT_PATH="${CERTS_DIR:-certs}/client_cert.pem"
KEY_PATH="${CERTS_DIR:-certs}/client_key.pem"
CA_PATH="${CERTS_DIR:-certs}/ca_cert.pem"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}🔒 mTLS Gateway Security Test${NC}"
echo -e "${BLUE}======================================${NC}"
echo

# Function to check if certificates exist
check_certificates() {
    echo -e "${YELLOW}📋 Checking certificates...${NC}"
    
    if [[ ! -f "$CERT_PATH" ]]; then
        echo -e "${RED}❌ Client certificate not found: $CERT_PATH${NC}"
        exit 1
    fi
    
    if [[ ! -f "$KEY_PATH" ]]; then
        echo -e "${RED}❌ Client key not found: $KEY_PATH${NC}"
        exit 1
    fi
    
    if [[ ! -f "$CA_PATH" ]]; then
        echo -e "${RED}❌ CA certificate not found: $CA_PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All certificates found${NC}"
    echo
}

# Function to test authorized connection
test_authorized() {
    echo -e "${YELLOW}🔐 Testing AUTHORIZED connection (with client certificate)...${NC}"
    echo -e "${BLUE}Command: curl -s -o /dev/null -w \"%{http_code}\" --cert $CERT_PATH --key $KEY_PATH --cacert $CA_PATH https://$DOMAIN$API_ENDPOINT${NC}"
    echo
    
    # Get HTTP status code only for authorized connection
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --cert "$CERT_PATH" --key "$KEY_PATH" --cacert "$CA_PATH" "https://$DOMAIN$API_ENDPOINT" 2>/dev/null)
    
    echo -e "${BLUE}HTTP Status Code: $http_code${NC}"
    echo
    
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ AUTHORIZED ACCESS: HTTP $http_code - SUCCESS${NC}"
        echo -e "${GREEN}🎉 Client certificate authentication working!${NC}"
        return 0
    else
        echo -e "${RED}❌ AUTHORIZED ACCESS: HTTP $http_code - FAILED${NC}"
        return 1
    fi
}

# Function to test unauthorized connection
test_unauthorized() {
    echo -e "${YELLOW}🚫 Testing UNAUTHORIZED connection (without client certificate)...${NC}"
    echo -e "${BLUE}Command: curl -s https://$DOMAIN$API_ENDPOINT${NC}"
    echo
    
    # Try unauthorized connection and capture exit code
    curl -s -o /dev/null "https://$DOMAIN$API_ENDPOINT" >/dev/null 2>&1
    curl_exit_code=$?
    
    echo -e "${BLUE}Curl exit code: $curl_exit_code${NC}"
    echo
    
    # For mTLS, we expect curl to fail (non-zero exit code)
    if [[ $curl_exit_code -ne 0 ]]; then
        echo -e "${GREEN}✅ UNAUTHORIZED ACCESS: BLOCKED (exit code $curl_exit_code) - SUCCESS${NC}"
        echo -e "${GREEN}🛡️  mTLS security is working correctly!${NC}"
        return 0
    else
        echo -e "${RED}❌ UNAUTHORIZED ACCESS: ALLOWED - SECURITY BREACH${NC}"
        echo -e "${RED}⚠️  WARNING: Unauthorized access should be blocked!${NC}"
        return 1
    fi
}

# Function to show summary
show_summary() {
    echo
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}📊 Test Summary${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    if [[ $authorized_result -eq 0 && $unauthorized_result -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED${NC}"
        echo -e "${GREEN}✅ Authorized access: Working${NC}"
        echo -e "${GREEN}✅ Unauthorized access: Blocked${NC}"
        echo -e "${GREEN}🔒 Your mTLS gateway is secure and functional!${NC}"
    elif [[ $authorized_result -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  PARTIAL SUCCESS${NC}"
        echo -e "${GREEN}✅ Authorized access: Working${NC}"
        echo -e "${RED}❌ Unauthorized access: Not properly blocked${NC}"
        echo -e "${YELLOW}🔧 Security configuration needs attention${NC}"
    elif [[ $unauthorized_result -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  PARTIAL SUCCESS${NC}"
        echo -e "${RED}❌ Authorized access: Not working${NC}"
        echo -e "${GREEN}✅ Unauthorized access: Blocked${NC}"
        echo -e "${YELLOW}🔧 Certificate configuration needs attention${NC}"
    else
        echo -e "${RED}❌ ALL TESTS FAILED${NC}"
        echo -e "${RED}❌ Authorized access: Not working${NC}"
        echo -e "${RED}❌ Unauthorized access: Not properly blocked${NC}"
        echo -e "${RED}🚨 mTLS configuration needs immediate attention${NC}"
    fi
    echo
}

# Main execution
main() {
    check_certificates
    
    # Test authorized connection
    test_authorized
    authorized_result=$?
    echo
    
    # Test unauthorized connection
    test_unauthorized
    unauthorized_result=$?
    
    # Show summary
    show_summary
    
    # Exit with appropriate code
    if [[ $authorized_result -eq 0 && $unauthorized_result -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main