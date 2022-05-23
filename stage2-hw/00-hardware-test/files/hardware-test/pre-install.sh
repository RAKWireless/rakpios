#!/bin/bash
if [ $USER != "root" ]
then
	echo "please use root user to run!"
	exit
fi
echo "start install..."
apt-get install -y build-essential python-dev python3-smbus python3-pip libjpeg62-turbo-dev iperf3 hwinfo
pip3 install pyserial
pip3 install smbus
pip3 install smbus2
pip3 install adafruit-ads1x15
pip3 install adafruit-circuitpython-bme280
pip3 install RPi.GPIO
pip3 install gpiod
pip3 install adafruit-circuitpython-shtc3
pip3 install psutil
pip3 install iperf3
pip3 install adafruit-extended-bus
pip3 install adafruit-circuitpython-atecc
#ssd1306 dependency
pip3 install luma.core
pip3 install luma.oled
#rak13300 dependency
pip3 install LoRaRF 
echo "end install."

