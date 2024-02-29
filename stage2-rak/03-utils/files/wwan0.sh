#!/usr/bin/env bash

interface=$1
event=$2

if [[ "$interface" != "wwan0" ]] || [[ $event != "up" ]]; then
    exit 0
fi

if [[ -f /sys/class/net/wwan0/qmi/raw_ip ]]; then
    ifconfig wwan0 down
    echo 1 > /sys/class/net/wwan0/qmi/raw_ip
    ifconfig wwan0 up
fi
