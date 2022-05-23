#!/usr/bin/bash
list=0
mode="once"
count=1024
usage()
{
cat << EOF
Usage: 
  ./test_disk [options]

Options:
  -l		List available disc device to test
  -m [mode]     Either "continuous" or "once" (defaults to "once"). 
                In "continuous" mode the script should run until all disk space is used
                In "once" mode the script will stop after once write/read round.
  -h            This help		
EOF
}


if [ $USER != "root" ]
then
    echo "please use root user to run!"
    exit
fi

if ! [ -x "$(command -v hwinfo)" ] 
then
    echo "hwinfo is not installed,now start installing..."
    apt install -y hwinfo >/dev/null 2>&1
fi

if [ $# -eq 1 ]
then
	case $1 in 
	-h)
		echo "-h"
		usage
		exit 0
		;;
	-l)
		list=1
		;;
	*)
		echo "invalid option"
		exit 1
		;;
	esac
elif [ $# -eq 2 ]
then 
	if [ $1 != "-m" ]
	then
		echo "invalid option"
		exit 1
	fi
	if [ $2 != "once" -a $2 != "continuous" ]
	then 
		echo "invalid mode"
		exit 1
	fi
	mode=$2
fi

num=`lsblk | grep disk | grep -v boot | wc -l`
names=`lsblk | grep disk | grep -v boot | awk '{print $1}'`
sizes=`lsblk | grep disk | grep -v boot | awk '{print $4}'`

echo "Discovery Disc Device..."

for((i=1;i<=$num;i++));
do
   	name=$(echo $names | awk '{print $'$i'}')
	size=$(echo $sizes | awk '{print $'$i'}')
	vendor=$(hwinfo --short | grep -w $name | awk '{print $2}')
	echo "[$i] name:$name    size:$size    vendor:$vendor"
done

if [ $list -eq 1 ]
then 
	exit 0
fi

echo -e "\n"

echo "which disc do you want to test? please input ID:"
select dev in $names
do
	if [ ! -n "$dev" ];then
		echo "invalid input!"
		exit 1
	fi
	echo ""
	cnt=$(lsblk | grep $dev | grep part | wc -l)	

	part=$dev"1"
	if [ $mode == "continuous" ];then
		#avail=$(df -h | grep /dev/sda1 | awk '{print $4}')
		avail="2G"
		v1=${avail%?}
		
		v2=$(echo $v1 | cut -d '.' -f1)
		
		cnt=$((${v2}*1024))
		echo $cnt
	fi

	if [ $dev == "mmcblk0" ];then
		part=$dev"p2"
		echo "-mode:$mode"
		echo ""
		echo "-start test..."
		write=$(dd if=/dev/zero of=/home/rak/largefile bs=1M count=$count 2>&1)
		ts=$(echo $write | awk 'END {print $16}')
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
        echo ""
        read=$(dd if=/home/rak/largefile of=/dev/null bs=1M 2>&1)
        rs=$(echo $read | awk 'END {print $16}')
		rm -f /home/rak/largefile

	else
		part=$dev"1"
		mount=$(lsblk | grep $part | awk '{print $7}')
    	if [ ! -n "$mount" ]; then
			mkdir -p /mnt/$part
        	mount /dev/$part /mnt/$part
    	fi
		echo "-mode:$mode" 
		echo ""
		echo "-start test..."
    	write=$(dd if=/dev/zero of=/mnt/$part/largefile bs=1M count=$count 2>&1)
		ts=$(echo $write | awk 'END {print $16}')
		sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
		read=$(dd if=/mnt/$part/largefile of=/dev/null bs=1M 2>&1)
		rs=$(echo $read | awk 'END {print $16}')
		rm -f /mnt/$part/largefile
	fi

	echo -e "\n"
	echo "Write speed: $ts MB/s"
	echo "Read speed: $rs MB/s"

	break
done
