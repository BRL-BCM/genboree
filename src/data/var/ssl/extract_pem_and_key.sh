#!/bin/bash

set -e
#set -v


if [[ $# -ne 2 ]]; 
then
    echo "Parameters:  KEYPAIR_NAME  CA_NAME"
    exit 1
fi


if [ "$(whoami)" != "genboree" ];
then
    echo "Script must be run as genboree user"
    exit 2
fi


SSL_BASE_DIR=.
KEYSTORE=$SSL_BASE_DIR/jks/client.keystore.jks

KEYPAIR_NAME=$1
CA_NAME=$2

# Use openssl to extract the cert file from the PKCS12 file as a PEM (.pem)
# - Tell it NOT to output the private key part!
PKCS12_DEST=$SSL_BASE_DIR/jks/$KEYPAIR_NAME%$CA_NAME.p12
PEM_DEST=$SSL_BASE_DIR/jks/$KEYPAIR_NAME%$CA_NAME.pem
openssl pkcs12 -in $PKCS12_DEST -nokeys -out $PEM_DEST
chmod 644 $PEM_DEST
# Can verify (and should see SIGNATURE!) the cert .pem file was generated ok by dumping it:
# openssl x509 -in $PEM_DEST -text

# Generate the matching private key, password protected
# - Here we tell it not to include the cert part
PKCS12_DEST=$SSL_BASE_DIR/jks/$KEYPAIR_NAME.p12
openssl pkcs12 -in $PKCS12_DEST -nocerts -out $SSL_BASE_DIR/jks/$KEYPAIR_NAME.key
chmod 640 $SSL_BASE_DIR/jks/$KEYPAIR_NAME.key

