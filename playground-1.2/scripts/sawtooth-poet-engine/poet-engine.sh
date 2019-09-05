#!/bin/sh

while [ ! -f /poet-shared/validator-0/keys/validator.priv ]; do
  echo 'waiting for validator key';
  sleep 1;
done

poet-engine -v -C tcp://$HOSTNAME:5050 --component tcp://$HOSTNAME:4004
