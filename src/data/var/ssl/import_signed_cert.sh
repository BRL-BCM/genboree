#!/bin/bash

set -e
#set -v


if [[ $# -ne 2 ]]; 
then
    echo "Parameters:  KEYPAIR_NAME  CA_NAME"
    echo "java1.7+ is required"
    exit 1
fi


SSL_BASE_DIR=.
KEYSTORE=$SSL_BASE_DIR/jks/client.keystore.jks

KEYPAIR_NAME=$1
CA_NAME=$2

if [ ! -f $SSL_BASE_DIR/csrs/$KEYPAIR_NAME%$CA_NAME-signed.crt ]; then
    echo "File $SSL_BASE_DIR/csrs/$KEYPAIR_NAME%$CA_NAME-signed.crt does not exists! It must contain signed certificate!"
    exit 2
fi

if [ ! -f $SSL_BASE_DIR/ca/pub/$CA_NAME.crt ]; then
    echo "File $SSL_BASE_DIR/ca/pub/$CA_NAME.crt does not exists! It must contain CA public key!"
    exit 3
fi


# Also need to import the CA public key into the KEYstore (if you got it).
keytool -keystore $KEYSTORE -alias $CA_NAME -import -file $SSL_BASE_DIR/ca/pub/$CA_NAME.crt

# Import the signed cert into your client keystore.
keytool -keystore $KEYSTORE -alias $KEYPAIR_NAME%$CA_NAME -import -file $SSL_BASE_DIR/csrs/$KEYPAIR_NAME%$CA_NAME-signed.crt

# Confirm two records in your client.keystore.jks
# keytool -list -keystore $KEYSTORE

# Get dev-client keypair as PKCS12 private key-cert password protected file
PKCS12_DEST=$SSL_BASE_DIR/jks/$KEYPAIR_NAME%$CA_NAME.p12
keytool -importkeystore -srckeystore $KEYSTORE -destkeystore $PKCS12_DEST -deststoretype PKCS12 -srcalias $KEYPAIR_NAME%$CA_NAME
chmod 640 $PKCS12_DEST
PKCS12_DEST=$SSL_BASE_DIR/jks/$KEYPAIR_NAME.p12
keytool -importkeystore -srckeystore $KEYSTORE -destkeystore $PKCS12_DEST -deststoretype PKCS12 -srcalias $KEYPAIR_NAME
chmod 640 $PKCS12_DEST

# set ownership to genboree
chown genboree:genboree -R $SSL_BASE_DIR

echo "Run extract_pem_and_key.sh as genboree user to finalize the process!"
