#!/bin/bash

if [ ! -d "$SAWTOOTH_HOME/logs" ]; then
    mkdir -p $SAWTOOTH_HOME/logs
fi

if [ ! -d "$SAWTOOTH_HOME/keys" ]; then
    mkdir -p $SAWTOOTH_HOME/keys
fi

if [ ! -f "$SAWTOOTH_HOME/keys/validator.priv" ]; then
    echo 'No validator private key found, generating one';
    sawadm keygen;
fi

if [ ! -d "$SAWTOOTH_HOME/policy" ]; then
    mkdir -p $SAWTOOTH_HOME/policy
fi

if [ ! -d "$SAWTOOTH_HOME/data" ]; then
    mkdir -p $SAWTOOTH_HOME/data
fi

if [ ! -d "$SAWTOOTH_HOME/etc" ]; then
    mkdir -p $SAWTOOTH_HOME/etc
fi

if [ ! -e /opt/config-genesis.batch ]; then
    echo "No config-genesis.batch file"
    sawset genesis -k $SAWTOOTH_HOME/keys/validator.priv -o /opt/config-genesis.batch;
fi

if [ ! -e /opt/config.batch ]; then
    echo "Going to create a proposal with initial settings"
    sawset proposal create \
    -k $SAWTOOTH_HOME/keys/validator.priv \
    sawtooth.consensus.algorithm.name=Devmode \
    sawtooth.consensus.algorithm.version=0.1 \
    -o /opt/config.batch

    sawadm genesis /opt/config-genesis.batch /opt/config.batch
fi

printenv
rm $SAWTOOTH_HOME/etc/validator.toml
if [ ! -e "$SAWTOOTH_HOME/etc/validator.toml" ]; then
    echo "Creating a sawtooth validator.toml configuration file"
    touch $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_url = \"${OPENTSDB_URL}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_db = \"${OPENTSDB_DB}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_username = \"${OPENTSDB_USERNAME}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_password = \"${OPENTSDB_PW}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "network_public_key = \"${NETWORK_PUBLIC_KEY}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "network_private_key = \"${NETWORK_PRIVATE_KEY}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    cat $SAWTOOTH_HOME/etc/validator.toml
fi

if [ ! -e "$SAWTOOTH_HOME/logs/validator-debug.log" ]; then
    echo "Creating the validator-debug.log"
    touch $SAWTOOTH_HOME/logs/validator-debug.log
fi

if [ ! -e /root/.sawtooth/keys/root.priv ]; then
    echo "No sawtooth key was found"
    if [ -e /opt/root.priv ]; then
        echo "Fetching the key from /opt"
        mkdir -p /root/.sawtooth/keys
        cp /opt/root.priv /root/.sawtooth/keys/root.priv
        cp /opt/root.pub /root/.sawtooth/keys/root.pub
    else
        echo "Generating a new key"
        sawtooth keygen root
        cp /root/.sawtooth/keys/root.priv /opt/root.priv
        cp /root/.sawtooth/keys/root.pub /opt/root.pub
    fi
fi

SH="$SAWTOOTH_HOME"
env="$ENVIRONMENT"
cat <<EOF > $SAWTOOTH_HOME/etc/log_config.toml
version = 1
disable_existing_loggers = false

[formatters.simple]
format = "[%(asctime)s.%(msecs)03d [%(threadName)s] %(module)s %(levelname)s] %(message)s"
datefmt = "%H:%M:%S"

[formatters.json]
format = "{\"timestamp\":\"%(asctime)s.%(msecs)03d\",\"app\":\"sidechain\",\"env\":\"staging\",\"name\":\"validator\",\"module\":\"%(module)s\",\"levelname\":\"%(levelname)s\",\"message\":\"%(message)s\"}"
datefmt = "%Y-%m-%dT%H:%M:%S"

[formatters.newformat]
format = "[%(asctime)s.%(msecs)03d] [%(levelname)s] [sidechain] [%(module)s] [staging] %(message)s"
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
    --endpoint tcp://validator.staging.sidechain.propsproject.io:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --opentsdb-url http://sawtooth-metrics:8086 \
    --opentsdb-db metrics
