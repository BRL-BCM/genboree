#!/bin/bash

set -e
#set -v


if [[ $# -ne 1 ]]; 
then
    echo "Parameters:  KEYPAIR_NAME"
    echo "java1.7+ is required"
    exit 1
fi


SSL_BASE_DIR=.
KEYSTORE=$SSL_BASE_DIR/jks/client.keystore.jks

KEYPAIR_NAME=$1

if [ -f $SSL_BASE_DIR/csrs/$KEYPAIR_NAME.csr ]; then
    echo "File $SSL_BASE_DIR/csrs/$KEYPAIR_NAME.csr already exists! Delete it first!"
    exit 2
fi

# Answer cert metadata questions consistently.
keytool -keystore $KEYSTORE -alias $KEYPAIR_NAME -validity 3650 -genkey -keysize 2048 -keyalg RSA

# Generate CSR for this client cert:
keytool -keystore $KEYSTORE -alias $KEYPAIR_NAME -certreq -file $SSL_BASE_DIR/csrs/$KEYPAIR_NAME.csr

echo "OK!"
echo "Submit $SSL_BASE_DIR/csrs/$KEYPAIR_NAME.csr to get it signed"
echo "Copy the response to the following directories:"
echo "  -> $SSL_BASE_DIR/csrs/$KEYPAIR_NAME%$CA_NAME-signed.csr"
echo "  -> $SSL_BASE_DIR/ca/pub/$CA_NAME.crt" 
