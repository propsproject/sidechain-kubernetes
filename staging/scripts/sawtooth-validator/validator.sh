#!/bin/bash

if [ ! -d "$SAWTOOTH_HOME/logs" ]; then
    mkdir -p $SAWTOOTH_HOME/logs
fi

if [ ! -d "$SAWTOOTH_HOME/keys" ]; then
    mkdir -p $SAWTOOTH_HOME/keys
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

mkdir -p /poet-shared/validator-0 || true
cp -a $SAWTOOTH_HOME/keys /poet-shared/validator-0

while [ ! -f /poet-shared/poet-enclave-measurement ]; do
    echo 'waiting for poet-enclave-measurement';
    sleep 1;
done

while [ ! -f /poet-shared/poet-enclave-basename ]; do
    echo 'waiting for poet-enclave-basename';
    sleep 1;
done

while [ ! -f /poet-shared/poet.batch ]; do
    echo 'waiting for poet.batch';
    sleep 1;
done

cp /poet-shared/poet.batch /

if [ ! -e config-genesis.batch ]; then
    sawset genesis -k $SAWTOOTH_HOME/keys/validator.priv -o config-genesis.batch;
fi

if [ ! -e config.batch ]; then
    sawset proposal create \
    -k $SAWTOOTH_HOME/keys/validator.priv \
    sawtooth.consensus.algorithm.name=PoET \
    sawtooth.consensus.algorithm.version=0.1 \
    sawtooth.poet.report_public_key_pem="$(cat /poet-shared/simulator_rk_pub.pem)" \
    sawtooth.poet.valid_enclave_measurements=$(cat /poet-shared/poet-enclave-measurement) \
    sawtooth.poet.valid_enclave_basenames=$(cat /poet-shared/poet-enclave-basename) \
    sawtooth.poet.initial_wait_time=15 \
    sawtooth.poet.target_wait_time=15 \
    sawtooth.publisher.max_batches_per_block=200 \
    sawtooth.poet.key_block_claim_limit=100000 \
    sawtooth.poet.ztest_minimum_win_count=100000 \
    -o config.batch;
fi

if [ ! -e "$SAWTOOTH_HOME/etc/validator.toml" ]; then
    touch $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_url = \"${OPENTSDB_URL}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_db = \"${OPENTSDB_DB}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_username = \"${OPENTSDB_USERNAME}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    echo "opentsdb_password = \"${OPENTSDB_PW}\"" >> $SAWTOOTH_HOME/etc/validator.toml
    cat $SAWTOOTH_HOME/etc/validator.toml
fi

if [ ! -e "$SAWTOOTH_HOME/logs/validator-debug.log" ]; then
    touch $SAWTOOTH_HOME/logs/validator-debug.log
fi

if [ ! -e "$SAWTOOTH_HOME/data/block-chain-id" ]; then
    sawadm genesis config-genesis.batch config.batch poet.batch;
fi

if [ ! -e /root/.sawtooth/keys/my_key.priv ]; then
   sawtooth keygen my_key; \
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
    --endpoint tcp://$SAWTOOTH_VALIDATOR_SERVICE_HOST:8800 \
    --bind component:tcp://eth0:4004 \
    --bind consensus:tcp://eth0:5050 \
    --bind network:tcp://eth0:8800 \
    --opentsdb-url http://sawtooth-metrics:8086 \
    --opentsdb-db metrics