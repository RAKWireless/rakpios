#!/bin/bash
if [ $USER != "root" ]
then
	echo "Please use root user to run!"
	exit
fi
echo "This script will enable your i2c bus0" 

ret=$(grep -v '^#' /boot/config.txt |grep 'dtparam=i2c_vc=on')
if [ ! $ret ]
then
    sed -i '/^[^#]*dtparam=i2c_arm=on/ a dtparam=i2c_vc=on' /boot/config.txt
    echo "Done, i2c bus 0 enabled"
else
    echo "i2c bus0 is already enabled, no need to make any changes" 
    exit
fi
echo "The last step is to reboot your pi to enable new changes"
