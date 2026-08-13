#!/bin/bash
# setup-certificates.sh

set -e

# === Configuration ===
ROOT_CA_DIR="$HOME/setup/lab-ca"
OUTPUT_DIR="$ROOT_CA_DIR/output"
DOMAIN="<mydomain.com>"
PASSWORD="<the-password>"
KEY_SIZE=2048
DAYS_VALID=3650

# Hosts to generate certs for: label=SANs
declare -A CERT_HOSTS=(
 ["sso-1-a.${DOMAIN}"]="DNS:sso-1-a.${DOMAIN},IP:<sso-1-a_IP>"
 ["sso-2-a.${DOMAIN}"]="DNS:sso-2-a.${DOMAIN},IP:<sso-2-a_IP>"
 ["sso-3-a.${DOMAIN}"]="DNS:sso-3-a.${DOMAIN},IP:<sso-3-a_IP>"
 ["sso-4-a.${DOMAIN}"]="DNS:sso-4-a.${DOMAIN},IP:<sso-4-a_IP>"
 ["sso-1-b.${DOMAIN}"]="DNS:sso-1-b.${DOMAIN},IP:<sso-1-b_IP>"
 ["sso-2-b.${DOMAIN}"]="DNS:sso-2-b.${DOMAIN},IP:<sso-2-b_IP>"
 ["sso-3-b.${DOMAIN}"]="DNS:sso-3-b.${DOMAIN},IP:<sso-3-b_IP>"
 ["sso-4-b.${DOMAIN}"]="DNS:sso-4-b.${DOMAIN},IP:<sso-4-b_IP>"
 ["sso-lb-a.${DOMAIN}"]="DNS:sso-lb-a.${DOMAIN},DNS:*.${DOMAIN},IP:<sso-lb-a_IP>"
 ["sso-lb-b.${DOMAIN}"]="DNS:sso-lb-b.${DOMAIN},DNS:*.${DOMAIN},IP:<sso-lb-b_IP>"
 ["sso-infra.${DOMAIN}"]="DNS:sso-infra.${DOMAIN},DNS:*.${DOMAIN},IP:<sso-infra_IP>"
 ["apps-1-a.${DOMAIN}"]="DNS:apps-1-a.${DOMAIN},DNS:*.${DOMAIN},IP:<apps-1-a_IP>"
 ["apps-1-b.${DOMAIN}"]="DNS:apps-1-b.${DOMAIN},DNS:*.${DOMAIN},IP:<apps-1-b_IP>"
 ["sso-global-1.${DOMAIN}"]="DNS:sso-global-1.${DOMAIN},DNS:apps-1-a.${DOMAIN},DNS:apps-1-b.${DOMAIN},DNS:sso-infra.${DOMAIN}"
)

# === Step 1: CA structure ===
echo ">> Preparing Root CA directories..."
mkdir -p "$ROOT_CA_DIR"/{certs,crl,newcerts,private,output}
cd "$ROOT_CA_DIR"
touch index.txt
echo 1000 > serial
chmod 700 private

=== Step 2: Create Root CA Config ===
cat > openssl-root-ca.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = .
certs             = \$dir/certs
crl_dir           = \$dir/crl
database          = \$dir/index.txt
new_certs_dir     = \$dir/newcerts
certificate       = \$dir/ca.crt
serial            = \$dir/serial
private_key       = \$dir/private/ca.key
RANDFILE          = \$dir/private/.rand

default_md        = sha256
policy            = policy_loose
x509_extensions   = v3_ca
default_days      = $DAYS_VALID

[ policy_loose ]
commonName        = supplied

[ req ]
distinguished_name = req_distinguished_name
x509_extensions    = v3_ca
prompt             = no

[ req_distinguished_name ]
CN = Lab Root CA

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = CA:true
keyUsage               = keyCertSign, cRLSign
EOF

# === Step 3: Generate Root CA ===
echo ">> Creating Root CA key and certificate..."
openssl genrsa -out private/ca.key 4096
openssl req -config openssl-root-ca.cnf -key private/ca.key -new -x509 -days $DAYS_VALID -sha256 -extensions v3_ca -out ca.crt

# === Step 4: Generate Certificates ===
for HOST in "${!CERT_HOSTS[@]}"; do
  HOST_DIR="$OUTPUT_DIR/$HOST"
  mkdir -p "$HOST_DIR"
  ALT_NAMES=${CERT_HOSTS[$HOST]}

  echo ">> [$HOST] Generating private key..."
  openssl genrsa -out "$HOST_DIR/server.key" $KEY_SIZE

  cat > "$HOST_DIR/req.cnf" <<EOF
[ req ]
distinguished_name = req_distinguished_name
prompt = no
req_extensions = v3_req

[ req_distinguished_name ]
CN = $HOST.$DOMAIN

[ v3_req ]
subjectAltName = ${ALT_NAMES}
EOF

  echo ">> [$HOST] Creating CSR..."
  openssl req -new -key "$HOST_DIR/server.key" -out "$HOST_DIR/server.csr" -config "$HOST_DIR/req.cnf"

  echo ">> [$HOST] Signing certificate..."
  openssl ca -batch -config "$ROOT_CA_DIR/openssl-root-ca.cnf" \
    -extensions v3_req -extfile "$HOST_DIR/req.cnf" \
    -in "$HOST_DIR/server.csr" -out "$HOST_DIR/server.crt"

  echo ">> [$HOST] Creating PKCS12 keystore..."
  openssl pkcs12 -export -out "$HOST_DIR/server.p12" \
    -inkey "$HOST_DIR/server.key" -in "$HOST_DIR/server.crt" \
    -certfile "$ROOT_CA_DIR/ca.crt" -passout pass:$PASSWORD
done

# === Step 5: Optional: Trust the CA ===
echo ">> To trust the CA system-wide on RHEL:"
echo "sudo cp $ROOT_CA_DIR/ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt && sudo update-ca-trust extract"

echo ">> DONE. Certificates created in: $OUTPUT_DIR"

