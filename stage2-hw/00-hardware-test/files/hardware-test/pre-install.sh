#!/bin/bash
if [ $USER != "root" ]; then
	echo "Use root user to install dependencies"
	exit
fi

apt-get install -y build-essential python-dev python3-smbus python3-pip libjpeg62-turbo-dev iperf3 hwinfo 
apt-get install -y python3-virtualenv
virtualenv .env
source .env/bin/activate
pip3 install -r requirements.txt


