#!/usr/bin/env python3

from optparse import OptionParser
import sys
import time
import adafruit_shtc3
from adafruit_extended_bus import ExtendedI2C as I2C

# Set default configuration value
ini_bus = 1
ini_count = 1
ini_delay = 1000

parser = OptionParser()
parser.add_option("-b", "--bus", type="int", dest="bus",
                  help="I2C channel (0 or 1, defaults to 1) ")
parser.add_option("-c", "--count", type="int", dest="count",
                  help="How many times to query the sensor (any natural number, defaults to 1, 0 means forever until "
                       "keyboard break)")
parser.add_option("-d", "--delay", type="int", dest="delay",
                  help="How often to query the sensor in ms (from 100ms to 10000ms, defaults to 1000ms)")
(options, args) = parser.parse_args()

while isinstance(options.bus, int):
    if options.bus in range(0, 2):
        ini_bus = options.bus
        break
    else:
        print("Invalid bus value")
        sys.exit()

while isinstance(options.count, int):
    if options.count >= 0:
        ini_count = options.count
        break
    else:
        print("Invalid count number")
        sys.exit()

while isinstance(options.delay, int):
    if options.delay in range(100, 10001):
        ini_delay = options.delay
        break
    else:
        print("Invalid duration value")
        sys.exit()


def get_temperature():
    if ini_bus == 1:
        i2c = I2C(1)
    elif ini_bus == 0:
        i2c = I2C(0)

    try:
        sht = adafruit_shtc3.SHTC3(i2c)
        temperature, relative_humidity = sht.measurements
        print("Temperature: %0.1f ºC, " % temperature + "Humidity: %0.1f %%" % relative_humidity)
        print("")
    except BaseException:
        print('Error: no I2C device at address: 0x70 on bus ' + str(ini_bus) + ', please check your i2c device')
        sys.exit()


try:
    if ini_count == 0:
        while True:
            get_temperature()
            time.sleep(ini_delay / 1000)
    else:
        for i in range(0, ini_count):
            get_temperature()
            time.sleep(ini_delay / 1000)

except KeyboardInterrupt:
    print("\n" + "Interrupted,exit...")
    pass

