# Domotic Mutual TLS Gateway 🏠🔐

A secure reverse proxy gateway that adds mutual TLS (mTLS) authentication to protect your home automation system. This solution uses Caddy as a reverse proxy to add client certificate authentication, ensuring only authorized devices can access your domotic APIs.

## Features

- 🔒 **Mutual TLS Authentication** - Client certificates required for access
- 🏠 **Home Automation Ready** - Works with Jeedom, Home Assistant, OpenHAB, and more
- 🛡️ **Security First** - Defense in depth approach with certificate-based authentication
- 📱 **Mobile Support** - Client certificates can be installed on mobile devices
- ⚙️ **Easy Setup** - Automated certificate generation and configuration
- 🔧 **Caddy Powered** - Modern, lightweight reverse proxy with automatic HTTPS

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/Gekkotron/DomoticMtlsGateway
   cd DomoticMtlsGateway
   ```

2. **Run the setup script**
   ```bash
   ./scripts/setup.sh
   ```
   This will create a `.env` file, prompt you to configure your gateway settings, and optionally generate the Caddyfile.

3. **Generate certificates**
   ```bash
   ./scripts/generate_certif.sh
   ```

4. **Start Caddy**
   ```bash
   caddy run --config Caddyfile
   ```

5. **Test the connection**
   ```bash
   ./scripts/test_cert_sni.sh
   ```

## Project Structure

```
DomoticMtlsGateway/
├── .env.example          # Environment configuration template
├── .env                  # Environment configuration (created by setup.sh)
├── Caddyfile.template    # Caddy configuration template
├── Caddyfile             # Generated Caddy configuration
├── README.md             # This file
├── scripts/              # All executable scripts
│   ├── setup.sh          # Interactive setup script (includes Caddyfile generation)
│   ├── generate_certif.sh # Certificate generation script
│   └── test_cert_sni.sh  # Connection testing script
├── certs/                # Generated certificates directory
│   ├── ca_cert.pem       # Certificate Authority certificate
│   ├── ca_key.pem        # Certificate Authority private key
│   ├── server_cert.pem   # Server certificate
│   ├── server_key.pem    # Server private key
│   ├── client_cert.pem   # Client certificate
│   └── client_key.pem    # Client private key
└── logs/                 # Access logs directory
    └── access.log        # Caddy access logs
```

## Configuration

### Environment Configuration

The project uses a `.env` file to configure all settings. Run `./scripts/setup.sh` to create and configure your environment file, or copy `.env.example` to `.env` and edit manually.

### **Understanding the Backend Configuration**

The mTLS gateway acts as a **secure proxy** in front of your home automation system:

```
[Mobile App] → [mTLS Gateway] → [Your Home Automation System]
 (internet)    (domotic.local)   (BACKEND_IP:BACKEND_PORT)
```

- **BACKEND_IP**: The IP address where your Jeedom/Home Assistant/OpenHAB is currently running
- **BACKEND_PORT**: The port your home automation system uses (usually 80 for HTTP or 8123 for Home Assistant)
- **BACKEND_PROTOCOL**: Usually `http` since your system runs locally without HTTPS

**Key Configuration Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMOTIC_HOST` | Domain name for your gateway | `domotic.local` |
| `DOMOTIC_PORT` | HTTPS port for the gateway | `443` |
| `BACKEND_IP` | **Hostname or IP where your home automation system runs** | `jeedom.local` |
| `BACKEND_PORT` | **Port where your home automation system listens** | `80` |
| `BACKEND_PROTOCOL` | **Protocol used by your home automation system** | `http` |
| `CERT_COUNTRY` | Certificate country code (ISO 3166-1 alpha-2, e.g. FR) | `FR` |
| `CERT_STATE` | Certificate state/province | `Rhône` |
| `CERT_CITY` | Certificate city | `RILLIEUX-LA-PAPE` |
| `CERT_ORG` | Certificate organization | `Gekkotron` |

### Caddyfile Configuration

The `Caddyfile` is automatically generated from `Caddyfile.template` using your environment settings:

- **Server Certificate**: Uses generated server certificate and key
- **Client Authentication**: Requires and verifies client certificates
- **CA Verification**: Uses the generated CA certificate to verify clients
- **Reverse Proxy**: Forwards authenticated requests to your configured backend

### Backend Configuration

The **backend** is your actual home automation system (Jeedom, Home Assistant, etc.) that runs behind the mTLS gateway.

**How to configure your backend:**

1. **Use the hostname (recommended):**
   ```bash
   # For Jeedom
   BACKEND_IP=jeedom.local
   BACKEND_PORT=80
   
   # For Home Assistant  
   BACKEND_IP=homeassistant.local
   BACKEND_PORT=8123
   
   # For OpenHAB
   BACKEND_IP=openhab.local
   BACKEND_PORT=8080
   ```

2. **Or use IP address if hostname doesn't work:**
   - Find IP: `ping jeedom.local` or check your router
   - Example: `BACKEND_IP=jeedom.local`

3. **Edit your `.env` file:**
   ```bash
   # Example for Jeedom
   BACKEND_IP=jeedom.local
   BACKEND_PORT=80
   BACKEND_PROTOCOL=http
   ```

2. **Regenerate the Caddyfile:**
   ```bash
   ./scripts/setup.sh  # Full reconfiguration (recommended)
   ```

**Common home automation system configurations:**

| System | BACKEND_IP | BACKEND_PORT | BACKEND_PROTOCOL |
|--------|------------|--------------|------------------|
| **Jeedom** | `jeedom.local` | `80` | `http` |
| **Home Assistant** | `homeassistant.local` | `8123` | `http` |
| **OpenHAB** | `openhab.local` | `8080` | `http` |

## Certificate Management

### Generating Certificates

The `scripts/generate_certif.sh` script creates:
1. **Certificate Authority (CA)** - Root certificate for signing
2. **Server Certificate** - For the gateway (domotic.local)
3. **Client Certificate** - For authenticated access

```bash
./scripts/generate_certif.sh
```

### Installing Client Certificates

#### On Mobile Devices
1. Transfer `client_cert.pem` and `client_key.pem` to your device
2. Install the client certificate in your device's certificate store
3. Configure your app to use the client certificate

#### On Desktop/Browser
1. Combine client certificate and key into PKCS#12 format:
   ```bash
   openssl pkcs12 -export -out client.p12 -inkey certs/client_key.pem -in certs/client_cert.pem
   ```
2. Import `client.p12` into your browser's certificate store

### Certificate Renewal

Certificates are valid for 10 years (3650 days). To renew:
1. Backup your current certificates
2. Run `./scripts/generate_certif.sh` to generate new certificates
3. Restart Caddy to load the new certificates

## Testing

### Comprehensive Security Test

Run the comprehensive security test to validate your mTLS setup:

```bash
./scripts/test_script.sh
```

**Expected Output:**
```
======================================
🔒 mTLS Gateway Security Test
======================================

📋 Checking certificates...
✅ All certificates found

🔐 Testing AUTHORIZED connection (with client certificate)...
Command: curl -s -o /dev/null -w "%{http_code}" --cert certs/client_cert.pem --key certs/client_key.pem --cacert certs/ca_cert.pem https://domotic.local/core/api/jeeApi.php

HTTP Status Code: 200

✅ AUTHORIZED ACCESS: HTTP 200 - SUCCESS
🎉 Client certificate authentication working!

🚫 Testing UNAUTHORIZED connection (without client certificate)...
Command: curl -s https://domotic.local/core/api/jeeApi.php

Curl exit code: 56

✅ UNAUTHORIZED ACCESS: BLOCKED (exit code 56) - SUCCESS
🛡️  mTLS security is working correctly!

======================================
📊 Test Summary
======================================
🎉 ALL TESTS PASSED
✅ Authorized access: Working
✅ Unauthorized access: Blocked
🔒 Your mTLS gateway is secure and functional!
```

### Basic Connection Test
```bash
./scripts/test_cert_sni.sh
```

### Manual Testing with curl
```bash
# Test with client certificate
curl --cert certs/client_cert.pem --key certs/client_key.pem https://domotic.local/

# Test without client certificate (should fail)
curl https://domotic.local/
```

### Simple Verbose Test

For detailed curl output showing the full TLS handshake:

```bash
./simple_test.sh
```

## Security Considerations

- **Certificate Storage**: Keep private keys secure and never commit them to version control
- **CA Security**: The CA private key (`ca_key.pem`) is critical - store it securely
- **Network Segmentation**: Consider isolating your home automation network
- **Regular Updates**: Keep Caddy and your home automation system updated
- **Certificate Rotation**: Plan for certificate renewal before expiration

## Troubleshooting

### Common Issues

1. **Certificate verification failed**
   - Ensure the CA certificate is correctly configured
   - Check that certificates haven't expired
   - Verify the hostname matches (domotic.local)

2. **Connection refused**
   - Check that Caddy is running
   - Verify the backend service is accessible
   - Check firewall settings

3. **Client certificate not accepted**
   - Ensure the client certificate was signed by the same CA
   - Check that the client certificate is properly formatted
   - Verify the certificate is installed correctly on the client

### Logs

Check Caddy logs for debugging:
```bash
tail -f logs/access.log
```

## Requirements

- **Caddy v2+** - Modern reverse proxy server
- **OpenSSL** - For certificate generation and testing
- **Home Automation System** - Jeedom, Home Assistant, OpenHAB, etc.

## License

This project is open source. Please check the repository for license details.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.