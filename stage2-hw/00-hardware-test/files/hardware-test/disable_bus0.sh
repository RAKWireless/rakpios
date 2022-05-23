#!/bin/bash
if [ $USER != "root" ]
then
	echo "Please use root user to run!"
	exit
fi
echo "This script will disable your i2c bus0" 

ret=$(grep -v '^#' /boot/config.txt |grep 'dtparam=i2c_vc=on')
if [ ! $ret ]
then
    echo "i2c bus0 is already disabled, no need to make any changes" 
    exit
else
    sed -i '/^dtpa.*_vc=on$/d' /boot/config.txt    
    echo "Done, i2c bus0 disabled"
fi
echo "The last step is to reboot your pi to enable new changes"
