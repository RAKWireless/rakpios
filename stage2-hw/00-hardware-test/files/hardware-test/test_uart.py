#!/usr/bin/env python3
import serial
import time
import sys
import threading
from random import Random
from optparse import OptionParser

 
def random_str(randomlength=32):
    str = ''
 
    chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789'
 
    length = len(chars) - 1
 
    random = Random()
 
    for i in range(randomlength):
        str+=chars[random.randint(0, length)] 
    return str

usage = "./test_uart [options] [device]"
parser = OptionParser(usage=usage)

parser.add_option("-l", "--list", action="store_true", dest="list", help="List available interfaces")
parser.add_option("-s", "--server", action="store_true", dest="server", help="Set the device in server mode.")
parser.add_option("-c", "--client", action="store_true", dest="client", help="Use client mode")


(options, args) = parser.parse_args()

if options.server == None and options.client == None:
	print("you need option '-s' or 'c'")
	sys.exit()
if len(args) == 0:
	print("argumen 'device' is mandatory")
	sys.exit()

device = args[0]

ser = serial.Serial(device,115200,timeout=1)

if options.client == True:
	while True:
		buf=random_str()
		ser.write(buf.encode('utf-8'))
		print("send   :%s"%buf)
		time.sleep(1)
		data = ser.read(128).decode('utf-8')
		print("recieve:%s"%data)
		print("")
		time.sleep(1)
if options.server == True:
	while True:
		data=ser.read(128).decode('utf-8')
		if len(data) > 0:
			print("recieve:%s"%data)
			ser.write(data.encode('utf-8'))
		time.sleep(1)

