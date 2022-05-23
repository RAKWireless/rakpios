#!/usr/bin/env python3
import serial
import time
import sys
import threading
from optparse import OptionParser

usage = "./test_sim [options] [device]"
parser = OptionParser(usage=usage)

parser.add_option("-b", "--baud", type="int", action="store", dest="baud", default=115200, help="Baudrate (defaults to RAK8213 default baudrate)")


(options, args) = parser.parse_args()

if len(args) == 0:
	print("argumen 'device' is mandatory")
	sys.exit()

device = args[0]
try:
	ser = serial.Serial(device,options.baud,timeout=1)
except Exception as e:
	print("ERROR: could not find the module.")
	sys.exit()
buf="ate0\r\n"
ser.write(buf.encode())
buf="at+cgsn\r\n"
ser.write(buf.encode())
print("send   :%s"%buf)
data = ser.read(128).decode()
if len(data) == 0:
	print("ERROR: can not read any data.");
	sys.exit()

if "OK" in data:
	data=data.replace('OK','')
	imei=data.replace('\r\n','')
	print("IMEI :%s"%imei)
else:
	print("ERROR: could not read imei data.")
