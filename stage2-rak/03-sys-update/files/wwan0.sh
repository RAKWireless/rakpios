#!/usr/bin/env bash

interface=$1
event=$2

if [[ "$interface" != "wwan0" ]] || [[ $event != "up" ]]
then
    return 0
fi

ifconfig wwan0 down
echo 1 > /sys/class/net/wwan0/qmi/raw_ip
ifconfig wwan0 up
