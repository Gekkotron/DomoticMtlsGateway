#!/bin/bash

# Detect script location and set proper paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo "❌ Error: .env file not found!"
    echo "Please run ./scripts/setup.sh first to create the configuration file."
    exit 1
fi

# Set defaults if not provided
CERT_COUNTRY=${CERT_COUNTRY:-US}
CERT_STATE=${CERT_STATE:-State}
CERT_CITY=${CERT_CITY:-City}
CERT_ORG=${CERT_ORG:-MyOrg}
CERT_UNIT=${CERT_UNIT:-MyUnit}
CA_COMMON_NAME=${CA_COMMON_NAME:-MyCA}
SERVER_COMMON_NAME=${SERVER_COMMON_NAME:-$DOMOTIC_HOST}
CLIENT_COMMON_NAME=${CLIENT_COMMON_NAME:-domotic-client}
CERT_VALIDITY_DAYS=${CERT_VALIDITY_DAYS:-3650}
CERTS_DIR=${CERTS_DIR:-certs}

# 1. Create the Certificate Authority (CA)
echo "🔐 Creating Certificate Authority..."
mkdir -p "$PROJECT_ROOT/$CERTS_DIR"
cd "$PROJECT_ROOT/$CERTS_DIR" || exit 1

openssl genrsa -out ca_key.pem 4096

openssl req -new -x509 -key ca_key.pem -out ca_cert.pem -days $CERT_VALIDITY_DAYS \
  -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_UNIT/CN=$CA_COMMON_NAME"


# 2. Create the Server Certificate
echo "🖥️  Creating server certificate for $SERVER_COMMON_NAME..."
openssl genrsa -out server_key.pem 2048

openssl req -new -key server_key.pem -out server.csr \
  -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_UNIT/CN=$SERVER_COMMON_NAME" \
  -addext "subjectAltName=DNS:$SERVER_COMMON_NAME,IP:127.0.0.1" 2>/dev/null || {
    # Fallback for older OpenSSL versions without -addext support
    openssl req -new -key server_key.pem -out server.csr \
      -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_UNIT/CN=$SERVER_COMMON_NAME"
}

# Try with copy_extensions first, fallback if not supported
openssl x509 -req -in server.csr -CA ca_cert.pem -CAkey ca_key.pem \
  -CAcreateserial -out server_cert.pem -days $CERT_VALIDITY_DAYS \
  -copy_extensions copy 2>/dev/null || {
    # Fallback for older OpenSSL versions
    openssl x509 -req -in server.csr -CA ca_cert.pem -CAkey ca_key.pem \
      -CAcreateserial -out server_cert.pem -days $CERT_VALIDITY_DAYS
}

# Verify server certificate was created
if [ ! -f server_cert.pem ]; then
    echo "❌ ERROR: Failed to generate server_cert.pem"
    exit 1
fi

rm server.csr

# 3. Create the Client Certificate
echo "📱 Creating client certificate for $CLIENT_COMMON_NAME..."

openssl genrsa -out client_key.pem 2048

openssl req -new -key client_key.pem -out client.csr \
  -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_UNIT/CN=$CLIENT_COMMON_NAME"

openssl x509 -req -in client.csr -CA ca_cert.pem -CAkey ca_key.pem \
  -CAcreateserial -out client_cert.pem -days $CERT_VALIDITY_DAYS

rm client.csr

cd "$PROJECT_ROOT"

echo "✅ Certificates generated successfully!"
echo "📁 Generated files in $CERTS_DIR/:"
echo "   - ca_cert.pem (Certificate Authority)"
echo "   - server_cert.pem (Server certificate for $SERVER_COMMON_NAME)"
echo "   - client_cert.pem (Client certificate for $CLIENT_COMMON_NAME)"