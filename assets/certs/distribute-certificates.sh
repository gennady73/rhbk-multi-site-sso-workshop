#!/bin/bash

USERNAME="<user-name>"
PASSWORD="<the-password>"
CA_FILE="ca.crt"
DOMAIN_NAME=".<mydomain.com>"

# Define remote machines and roles
declare -A SERVERS=(
  ["gu-sso-1-a${DOMAIN_NAME}"]="keycloak"
  ["gu-sso-2-a"${DOMAIN_NAME}]="keycloak"
  ["gu-sso-1-b"${DOMAIN_NAME}]="keycloak"
  ["gu-sso-2-b"${DOMAIN_NAME}]="keycloak"
  ["gu-sso-lb-a"${DOMAIN_NAME}]="haproxy"
  ["gu-sso-lb-b"${DOMAIN_NAME}]="haproxy"
#  ["gu-sso-mon-1"${DOMAIN_NAME}]="monitor"
#  ["gu-sso-infra"${DOMAIN_NAME}]="jenkins"
#  ["gu-apps-1-a"${DOMAIN_NAME}]="keycloak-demo"
#  ["gu-apps-1-b"${DOMAIN_NAME}]="keycloak-demo"
)

# Check if sshpass is installed
if ! command -v sshpass &>/dev/null; then
  echo "sshpass is required but not installed."
  exit 1
fi

# Loop over each server
for HOST in "${!SERVERS[@]}"; do
  ROLE="${SERVERS[$HOST]}"
  DEST_DIR="/opt/${ROLE}/conf"
  echo "==> Checking $HOST ($ROLE)..."

  # Ping check
  if ! ping -c 1 -W 1 "$HOST" &>/dev/null; then
    echo "    The Host $HOST is unreachable, skipping."
    continue
  fi

  echo "    The Host is reachable, copying files..."

  if [[ "$ROLE" == "keycloak" ]]; then
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST" "mkdir -p $DEST_DIR"
    sshpass -p "$PASSWORD" scp "output/$HOST/server.p12" "$USERNAME@$HOST:$DEST_DIR/server.keystore"
    sshpass -p "$PASSWORD" scp "$CA_FILE" "$USERNAME@$HOST:$DEST_DIR/ca.crt"
    
    #sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "sudo cp $DEST_DIR/ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt && sudo update-ca-trust extract"
    sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
    echo '$PASSWORD' | sudo -S cp $DEST_DIR/ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&
    echo '$PASSWORD' | sudo -S update-ca-trust extract
    "

  elif [[ "$ROLE" == "keycloak-demo" ]]; then
    DEST_DIR="/opt/app-deployment/certs"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST" "mkdir -p $DEST_DIR"
    sshpass -p "$PASSWORD" scp "output/$HOST/server.crt" "output/$HOST/server.key" "$USERNAME@$HOST:$DEST_DIR/"
    sshpass -p "$PASSWORD" scp "$CA_FILE" "$USERNAME@$HOST:$DEST_DIR/ca.crt"

    # Combine pem
    echo 'Combine pem'
    cat "output/$HOST/server.crt" "output/$HOST/server.key" "$CA_FILE" > "output/$HOST/app.pem"
    
    echo 'Copy pem'
    sshpass -p "$PASSWORD" scp "output/$HOST/app.pem" "$USERNAME@$HOST:$DEST_DIR/"

#    sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
#    echo '$PASSWORD' | sudo -S cp $DEST_DIR/ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&
#    echo '$PASSWORD' | sudo -S update-ca-trust extract
#    "
    sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
      if ! echo '$PASSWORD' | sudo -S test -f /etc/pki/ca-trust/source/anchors/lab-root-ca.crt; then
        echo 'CA not found. Installing...'
        echo '$PASSWORD' | sudo -S cp $DEST_DIR/ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&
        echo '$PASSWORD' | sudo -S update-ca-trust extract
      else
        echo 'CA already installed. Skipping update.'
      fi
    "

  elif [[ "$ROLE" == "haproxy" ]]; then
    TMPDIR="/home/$USERNAME/tmp/certdist-$HOST"
    #sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "echo '$PASSWORD' | sudo -S mkdir -p $TMPDIR"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST" "mkdir -p $TMPDIR"

    # Combine pem
    echo 'Combine pem'
    #cat "output/$HOST/server.crt" "output/$HOST/server.key" > "$TMPDIR/haproxy.pem"
    cat "output/$HOST/server.crt" "output/$HOST/server.key" "$CA_FILE" > "output/$HOST/haproxy.pem"
    
    echo 'Copy pem'
    #sshpass -p "$PASSWORD" scp "$TMPDIR/haproxy.pem" "$USERNAME@$HOST:/tmp/haproxy.pem"
    sshpass -p "$PASSWORD" scp "output/$HOST/haproxy.pem" "$USERNAME@$HOST:/tmp/haproxy.pem"
    sshpass -p "$PASSWORD" scp "$CA_FILE" "$USERNAME@$HOST:/tmp/lab-root-ca.crt"
    
    sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
    echo '$PASSWORD' | sudo -S mkdir -p /etc/haproxy/ssl &&
    echo '$PASSWORD' | sudo -S mv /tmp/haproxy.pem /etc/haproxy/ssl/haproxy.pem &&
    echo '$PASSWORD' | sudo -S chown root:haproxy /etc/haproxy/ssl/haproxy.pem &&
    echo '$PASSWORD' | sudo -S chmod 640 /etc/haproxy/ssl/haproxy.pem &&
    echo '$PASSWORD' | sudo -S chown root:haproxy /etc/haproxy/ssl &&
    echo '$PASSWORD' | sudo -S chmod 750 /etc/haproxy/ssl &&
    echo '$PASSWORD' | sudo -S restorecon -Rv /etc/haproxy/ssl
    echo '$PASSWORD' | sudo -S cp /tmp/lab-root-ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&
    echo '$PASSWORD' | sudo -S update-ca-trust extract
    "

    rm -rf "$TMPDIR"

  elif [[ "$ROLE" == "jenkins" ]]; then
    TMPDIR="/home/$USERNAME/tmp/certdist-$HOST"
    CERT_SOURCE="output/$HOST/server.p12"
    JKS_FILE="$TMPDIR/server.jks"
    CERT_DEST="output/$HOST"
    JENKINS_VOL="/home/$USERNAME/setup/containers/infra/jenkins-ci"
    STORE_PASS="password"

    #echo "Converting P12 for $HOST..."
    mkdir -p "$TMPDIR"
    
    echo "Validate source: '$CERT_SOURCE'"
    openssl pkcs12 -info -in "$CERT_SOURCE" -password pass:"$STORE_PASS" -nodes

    cp "$CERT_SOURCE" "$TMPDIR/server.p12"
    echo "Converting P12 for $HOST..."
    keytool -importkeystore \
      -srckeystore "$TMPDIR/server.p12" -srcstoretype PKCS12 \
      -destkeystore "$JKS_FILE" -deststoretype JKS \
      -srcstorepass "$STORE_PASS" -deststorepass "$STORE_PASS"
      -noprompt -validity 360 # -storepass "$STORE_PASS"

    # Local copy of jks file to the location where all certificates of given host resides
    yes | cp -rf "$JKS_FILE" "$CERT_DEST/server.jks"
    echo "Validate target keystore '$JKS_FILE'"
    keytool -list -v -keystore "$JKS_FILE" -storepass "$STORE_PASS"
    
    echo 'Copy Java Keystore(jks) to $HOST...'
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST" "mkdir -p $TMPDIR"
    sshpass -p "$PASSWORD" scp "$CERT_DEST/server.jks" "$USERNAME@$HOST:$JENKINS_VOL/server.jks"

    echo "Copy CA to '$HOST'..."
    sshpass -p "$PASSWORD" scp "$CA_FILE" "$USERNAME@$HOST:/tmp/lab-root-ca.crt"

    sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
      if ! echo '$PASSWORD' | sudo -S test -f /etc/pki/ca-trust/source/anchors/lab-root-ca.crt; then
        echo 'CA not found. Installing...'
	      echo '$PASSWORD' | sudo -S cp /tmp/lab-root-ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&
        echo '$PASSWORD' | sudo -S update-ca-trust extract
      else
        echo 'CA already installed. Skipping update.'
      fi
    "

  elif [[ "$ROLE" == "monitor" ]]; then
    DEST_DIR="/etc/prometheus/certs"  # as alternative use ~/setup/monitoring/containers/prometheus/certs/
    echo "    Configuring monitoring host..."
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$HOST" "echo '$PASSWORD' | sudo -S mkdir -p $DEST_DIR"
    
    echo "    Copying Root CA to $HOST..."
    sshpass -p "$PASSWORD" scp "$CA_FILE" "$USERNAME@$HOST:/tmp/lab-root-ca.crt"

    # Install the CA cert for Prometheus to use
    sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
      echo '$PASSWORD' | sudo -S mv /tmp/lab-root-ca.crt $DEST_DIR/lab-root-ca.crt &&
      echo '$PASSWORD' | sudo -S chown root:root $DEST_DIR/lab-root-ca.crt &&
      echo '$PASSWORD' | sudo -S chmod 644 $DEST_DIR/lab-root-ca.crt
    "

    # Optionally install it system-wide, as this is good practice
    # sshpass -p "$PASSWORD" ssh "$USERNAME@$HOST" "
    #   if ! echo '$PASSWORD' | sudo -S test -f /etc/pki/ca-trust/source/anchors/lab-root-ca.crt; then
    #     echo 'CA not found. Installing system-wide...'
    #     echo '$PASSWORD' | sudo -S cp $DEST_DIR/lab-root-ca.crt /etc/pki/ca-trust/source/anchors/lab-root-ca.crt &&
    #     echo '$PASSWORD' | sudo -S update-ca-trust extract
    #   else
    #     echo 'CA already installed. Skipping system-wide update.'
    #   fi
    # "

    rm -rf "$TMPDIR"
  fi

  echo "    Success. Certificate installed on $HOST"
done

