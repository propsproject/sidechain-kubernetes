#!/bin/sh

if [ ! -f /poet-shared/poet-enclave-measurement ]; then
  poet enclave measurement >> /poet-shared/poet-enclave-measurement;
fi

if [ ! -f /poet-shared/poet-enclave-basename ]; then
  poet enclave basename --enclave-module simulator >> /poet-shared/poet-enclave-basename;
fi

if [ ! -f /poet-shared/simulator_rk_pub.pem ]; then
  cp /etc/sawtooth/simulator_rk_pub.pem /poet-shared;
fi

while [ ! -f /poet-shared/validator-0/keys/validator.priv ]; do
  echo 'waiting for validator key';
  sleep 1;
done

cp -a /poet-shared/validator-0/keys /etc/sawtooth
poet registration create --enclave-module simulator -k /etc/sawtooth/keys/validator.priv -o /poet-shared/poet.batch

poet-engine -v -C tcp://$HOSTNAME:5050 --component tcp://$HOSTNAME:4004