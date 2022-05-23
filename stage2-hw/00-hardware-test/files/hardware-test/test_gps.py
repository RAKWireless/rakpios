#!/usr/bin/env python3
from smbus2 import SMBus
from optparse import OptionParser
import sys
import time


def query_GPS(GPS_bus, GPS_address):
    try:
        with SMBus(GPS_bus) as bus:
            payload = ''
            count = 0
            while True:
                try:
                    c = bus.read_byte(GPS_address)
                except BaseException:
                    print('Cannot detect I2C device on this address')
                    sys.exit()
                if (40 < c < 96) or c == 10 or c == 13:
                    # print(chr(c), end='')
                    payload += chr(c)
                    if chr(c).isspace():
                        count = count + 1
                        if count == 16:
                            break
            print(payload, '\n')
    except BaseException:
        print('Failed to detect i2c device, please check bus and address value')
        sys.exit()


usage = "./test_GPS [options]"
parser = OptionParser(usage=usage)
parser.add_option("-a", "--address", type="int", dest="address",
                  help="Address of the GPS in the bus (defaults to 0x42) ")

parser.add_option("-b", "--bus", type="int", dest="bus",
                  help="I2C channel (0 or 1, defaults to 1) ")

parser.add_option("-c", "--count", type="int", dest="count",
                  help="How many times to query the GPS (defaults to 1, 0 means forever until keyboard break)")

parser.add_option("-d", "--duration", type="int", dest="duration",
                  help="How often to query the GPS in ms (defaults to 1000),range is 10 to 10000")
(options, args) = parser.parse_args()

#####################################################################################

query_duration = 1000
query_count = 1
device_address = 0x42
GPS_bus = '/dev/i2c-1'

while isinstance(options.bus, int):
    if options.bus == 1:
        GPS_bus = '/dev/i2c-1'
        break
    elif options.bus == 0:
        GPS_bus = '/dev/i2c-0'
        break
    else:
        print("Invalid bus number, only support bus 1 and bus 0")
        sys.exit()

while isinstance(options.address, int):
    if options.address in range(0x00, 0x100):
        device_address = options.address
        break
    else:
        print('Invalid i2c bus address')
        sys.exit()

while isinstance(options.count, int):
    if options.count in range(0, 2):
        query_count = options.count
        break
    else:
        print('Invalid count value, should be either 1 or 0')
        sys.exit()

while isinstance(options.duration, int):
    if options.duration != 1000 and options.duration in range(10, 10001):
        query_duration = options.duration
        break
    elif options.duration == 1000:
        query_duration = 1000
        break
    elif options.duration not in range(10, 10001):
        print("Invalid duration value, should be range 10 to 10000 ms ")
        sys.exit()

#######################################################################################
#######################################################################################
#######################################################################################

if query_count == 1:
    for i in range(0, query_count):
        query_GPS(GPS_bus, device_address)
        time.sleep(query_duration / 1000)
elif query_count == 0:
    print('Enter continuous mode, runs forever until keyboard break', '\n')
    while True:
        query_GPS(GPS_bus, device_address)
        time.sleep(query_duration / 1000)

