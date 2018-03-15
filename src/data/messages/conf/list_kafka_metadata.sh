#!/bin/bash

set -e


if [[ $# -ne 3 ]]; 
then
    echo "Parameters:"
    echo " KAFKA_SERVICE (like exchange.clinicalgenome.org:9093)"
    echo " KEYPAIR_NAME (like test.genome.network)"
    echo " CA_NAME (like exchange.clinicalgenome.org)"
    exit 1
fi

EXT_CA_NAME=$3
EXT_SSL_SERVICE=$1
KEYPAIR_NAME=$2
echo "client SSL keystore pw? " ; read KSP
# List metadata (how much you see depends on server config, but should not error)
# - Should see some info about topics and partitions.
# - You can also try the metadata on a specific topic by adding: -t {topic}
kafkacat -L -b $EXT_SSL_SERVICE -X security.protocol=SSL \
-X ssl.ca.location=$SSL_BASE_DIR/ca/pub/$EXT_CA_NAME.crt \
-X ssl.certificate.location=$SSL_BASE_DIR/jks/$KEYPAIR_NAME%$EXT_CA_NAME.pem \
-X ssl.key.location=$SSL_BASE_DIR/jks/$KEYPAIR_NAME%$EXT_CA_NAME.key \
-X "ssl.key.password=$KSP"
