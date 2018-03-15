#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable


# SSL stuff (Kafka - 2018-01-05.sslKeypairSetup)
mkdir -p  $SSL_BASE_DIR
chmod 755 $SSL_BASE_DIR
chmod g+s $SSL_BASE_DIR
# Subdir for public key ("cert") of your CA. Even non-CA machines need this.
mkdir -p  $SSL_BASE_DIR/ca/pub/
chmod 755 $SSL_BASE_DIR/ca/pub/
# Subdir for Java KeyStore .jks and derived files:
mkdir -p   $SSL_BASE_DIR/jks/
chmod 2750 $SSL_BASE_DIR/jks/
# Subdir for incoming Certificate Signing Requests (CSRs) and the signed results.
mkdir      $SSL_BASE_DIR/csrs/
chmod 2750 $SSL_BASE_DIR/csrs/
# Subdir for the PRIVATE key file for your CA.
mkdir -p   $SSL_BASE_DIR/ca/priv/
chmod 0700 $SSL_BASE_DIR/ca/priv/
