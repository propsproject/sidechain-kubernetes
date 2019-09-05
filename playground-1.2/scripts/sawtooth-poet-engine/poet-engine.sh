#!/bin/sh

poet-engine -v -C tcp://$HOSTNAME:5050 --component tcp://$HOSTNAME:4004
