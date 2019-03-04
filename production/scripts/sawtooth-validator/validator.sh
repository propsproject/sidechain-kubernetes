#!/bin/sh
apt-get update
apt-get install bash curl -y

#!/bin/bash

if [ ! -e "$SAWTOOTH_HOME/validator.toml" ]; then
    echo ${OPENTSDB_USERNAME} >> $SAWTOOTH_HOME/validator.toml
    echo ${OPENTSDB_PW} >> $SAWTOOTH_HOME/validator.toml
fi

if [ ! -e "$SAWTOOTH_HOME/logs" ]; then
    mkdir -p $SAWTOOTH_HOME/logs
fi

if [ ! -e "$SAWTOOTH_HOME/keys" ]; then
    mkdir -p $SAWTOOTH_HOME/keys
fi

if [ ! -e "$SAWTOOTH_HOME/policy" ]; then
    mkdir -p $SAWTOOTH_HOME/policy
fi

if [ ! -e "$SAWTOOTH_HOME/data" ]; then
    mkdir -p $SAWTOOTH_HOME/data
fi

if [ ! -e "$SAWTOOTH_HOME/etc" ]; then
    mkdir -p $SAWTOOTH_HOME/etc
fi

if [ ! -e "$SAWTOOTH_HOME/logs/validator-debug.log" ]; then
    touch $SAWTOOTH_HOME/logs/validator-debug.log
fi

if [ ! -e "$SAWTOOTH_HOME/keys/validator.priv" ]; then
    sawadm keygen;
fi

if [ ! -e "$SAWTOOTH_HOME/data/block-chain-id" ]; then
    sawadm genesis
fi

poet enclave basename --enclave-module simulator
poet registration create --enclave-module simulator

SH="$SAWTOOTH_HOME"
env="$ENVIRONMENT"
cat <<EOF > $SAWTOOTH_HOME/etc/log_config.toml
version = 1
disable_existing_loggers = false

[formatters.simple]
format = "[%(asctime)s.%(msecs)03d [%(threadName)s] %(module)s %(levelname)s] %(message)s"
datefmt = "%H:%M:%S"

[formatters.json]
format = "{\"timestamp\":\"%(asctime)s.%(msecs)03d\",\"app\":\"sidechain\",\"env\":\"production\",\"name\":\"validator\",\"module\":\"%(module)s\",\"levelname\":\"%(levelname)s\",\"message\":\"%(message)s\"}"
datefmt = "%Y-%m-%dT%H:%M:%S"

[formatters.newformat]
format = "[%(asctime)s.%(msecs)03d] [%(levelname)s] [sidechain] [%(module)s] [production] %(message)s"
datefmt = "%Y-%m-%dT%H:%M:%S"

[handlers.debugrotate]
level = "DEBUG"
formatter = "newformat"
class = "logging.handlers.RotatingFileHandler"
filename = "/var/log/sawtooth/validator-debug.log"
maxBytes = 50000000
backupCount=20

[handlers.debug]
level = "DEBUG"
formatter = "json"
class = "logging.StreamHandler"
stream = "ext://sys.stdout"

[root]
level = "DEBUG"
propagate = true
handlers = [ "debug"]
EOF

sawtooth-validator  \
    --endpoint tcp://$PROPSCHAIN_VALIDATOR_SERVICE_HOST:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
#    --opentsdb-url http://sawtooth-metrics:8086 \
#    --opentsdb-db metrics \