#!/bin/sh
apt-get update
apt-get install bash curl -y

#!/bin/bash

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

if [ ! -e "$SAWTOOTH_HOME/etc/validator.toml" ]; then
    echo "[CREATING] Creating the validator.toml file"
    touch $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_url = \"${OPENTSDB_URL}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_db = \"${OPENTSDB_DB}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_username = \"${OPENTSDB_USERNAME}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_password = \"${OPENTSDB_PW}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    cat $SAWTOOTH_HOME/etc/validator.toml
fi


if [ ! -e "$SAWTOOTH_HOME/logs/validator-debug.log" ]; then
    echo "[CREATING] Creating the validator-debug.log file"
    touch $SAWTOOTH_HOME/logs/validator-debug.log
fi

if [ ! -e "$SAWTOOTH_HOME/keys/validator.priv" ]; then
    echo "[CREATING] Creating validator priv/pub keys"
    sawadm keygen;
fi

if [ ! -e "/opt/poet.batch" ]; then
    echo "[CREATING] Poet genesis batch file"

    poet enclave basename --enclave-module simulator
    poet registration create --enclave-module simulator -k /opt/sawtooth/keys/validator.priv -o /opt/poet.batch
fi

if [ ! -e /opt/config-genesis.batch ]; then
    echo "[CREATING] No config-genesis.batch file"
    sawset genesis -k $SAWTOOTH_HOME/keys/validator.priv -o /opt/config-genesis.batch;
fi

if [ ! -e /root/.sawtooth/keys/root.priv ]; then
    echo "No private key was found"
    if [ -e /opt/root.priv ]; then
        echo "Fetching the key from /opt"
        mkdir -p /root/.sawtooth/keys
        cp /opt/root.priv /root/.sawtooth/keys/root.priv
        cp /opt/root.pub /root/.sawtooth/keys/root.pub
    else
        echo "Generating a new key and adding the key to identity allowed keys"
        sawtooth keygen root
        cp /root/.sawtooth/keys/root.priv /opt/root.priv
        cp /root/.sawtooth/keys/root.pub /opt/root.pub
    fi
fi

if [ ! -e /opt/config.batch ]; then
    echo "[CREATING] Creating a config.batch file"
    sawset proposal create \
    -k $SAWTOOTH_HOME/keys/validator.priv \
    sawtooth.consensus.algorithm.name=pbft \
    sawtooth.consensus.algorithm.version=1.0 \
    sawtooth.consensus.pbft.block_publishing_delay=2000 \
    sawtooth.publisher.max_batches_per_block=200 \
    sawtooth.gossip.time_to_live=1 \
    sawtooth.consensus.pbft.members='["'$(cat ~/.sawtooth/keys/root.pub)'","'$(cat /opt/sawtooth/keys/validator.pub)'","0365a68ddcaeb5be58de09806667e3deb8f736fa4f705d02697a352dd7aaaa60df","02a7e0b9399f3b410a6842693baf56d24aa7ea178278f369e1e8bbc9f1736045ea","0249785b8ada0b8489d78c0273ec31505fa58acc63f0c2c99e21260792d2254b8f","03c383f6fea4128cfdc5f1202de072d2c7afdd8263a7296baa12a59ca49831f0a3"]' \
    sawtooth.settings.vote.authorized_keys=$(cat ~/.sawtooth/keys/root.pub),$(cat /opt/sawtooth/keys/validator.pub),,0365a68ddcaeb5be58de09806667e3deb8f736fa4f705d02697a352dd7aaaa60df,02a7e0b9399f3b410a6842693baf56d24aa7ea178278f369e1e8bbc9f1736045ea,0249785b8ada0b8489d78c0273ec31505fa58acc63f0c2c99e21260792d2254b8f,03c383f6fea4128cfdc5f1202de072d2c7afdd8263a7296baa12a59ca49831f0a3 \
    sawtooth.identity.allowed_keys=$(cat /opt/root.pub),$(cat /opt/sawtooth/keys/validator.pub),0365a68ddcaeb5be58de09806667e3deb8f736fa4f705d02697a352dd7aaaa60df,02a7e0b9399f3b410a6842693baf56d24aa7ea178278f369e1e8bbc9f1736045ea,0249785b8ada0b8489d78c0273ec31505fa58acc63f0c2c99e21260792d2254b8f,03c383f6fea4128cfdc5f1202de072d2c7afdd8263a7296baa12a59ca49831f0a3 \
    sawtooth.validator.transaction_families='[{"family": "pending-earnings", "version": "1.0"},{"family":"sawtooth_settings","version":"1.0"},{"family":"sawtooth_identity","version":"1.0"},{"family":"sawtooth_validator_registry","version":"1.0"}]' \
    -o /opt/config.batch

    sawadm genesis /opt/config-genesis.batch /opt/config.batch
    poet enclave basename --enclave-module simulator
    poet registration create --enclave-module simulator
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
format = "{\"timestamp\":\"%(asctime)s.%(msecs)03d\",\"app\":\"propschain\",\"env\":\"production\",\"name\":\"validator\",\"module\":\"%(module)s\",\"levelname\":\"%(levelname)s\",\"message\":\"%(message)s\"}"
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
    --endpoint tcp://validator-nlb.propschain.propsproject.io:8800 \
    --bind component:tcp://eth0:4004 \
    --bind network:tcp://eth0:8800 \
    --bind consensus:tcp://eth0:5050 \
    --scheduler parallel \
    -P static \
    --peers $VALIDATOR_PEER_URL \
    --opentsdb-url http://propschain-metrics:8086 \
    --opentsdb-db metrics
