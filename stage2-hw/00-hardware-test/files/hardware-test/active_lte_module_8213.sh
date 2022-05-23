#!/bin/sh

if [ $USER != "root" ]
then
    echo "please use root user to run!"
    exit
fi

cd /sys/class/gpio/

if [ -d /sys/class/gpio/gpio5 ]; then
    echo 5 > /sys/class/gpio/unexport
    sleep 0.2
fi
if [ -d /sys/class/gpio/gpio6 ]; then
    echo 6 > /sys/class/gpio/unexport
    sleep 0.2
fi
if [ -d /sys/class/gpio/gpio13 ]; then
    echo 13 > /sys/class/gpio/unexport
    sleep 0.2
fi
if [ -d /sys/class/gpio/gpio19 ]; then
    echo 19 > /sys/class/gpio/unexport
    sleep 0.2
fi
if [ -d /sys/class/gpio/gpio21 ]; then
    echo 21 > /sys/class/gpio/unexport
    sleep 0.2
fi
if [ -d /sys/class/gpio/gpio26 ]; then
    echo 26 > /sys/class/gpio/unexport
    sleep 0.2
fi
if [ -d /sys/class/gpio/gpio23 ]; then
    echo 23 > /sys/class/gpio/unexport
    sleep 0.2
fi



echo 5 > export
echo 6 > export
echo 13 > export
echo 19 > export
echo 23 > export
echo 21 > export
echo 26 > export
echo out > gpio5/direction
echo out > gpio6/direction
echo out > gpio13/direction
echo out > gpio19/direction
echo out > gpio23/direction
echo in > gpio21/direction
echo out > gpio26/direction

echo 0 > gpio5/value
echo 0 > gpio6/value
echo 0 > gpio13/value
echo 0 > gpio19/value
echo 0 > gpio26/value
echo 1 > gpio23/value

#
cd /sys/class/gpio/

echo "18" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio18/direction
echo 0 > /sys/class/gpio/gpio18/value
sleep 0.2
echo 1 > /sys/class/gpio/gpio18/value
sleep 0.2
echo 0 > /sys/class/gpio/gpio18/value

