#!/usr/bin/env bash

sudo iptables -I FORWARD -i ens3 -p tcp -j REJECT
