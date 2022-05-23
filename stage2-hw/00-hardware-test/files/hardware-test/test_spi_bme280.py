#!/usr/bin/env python3
from optparse import OptionParser
import time
import board
import digitalio
from adafruit_bme280 import basic as adafruit_bme280
import sys

usage = "./test_spi_bme280 [options]"
parser = OptionParser(usage=usage) 

parser.add_option("-b", "--bus", type = "int", action="store", dest="bus", help=" SPI channel to use (0 or 1)[mandatory]")
parser.add_option("-c", "--count", type = "int", action="store", dest="count", default=1, help="How many times to query the sensor (any natural number, defaults to 1, 0 means forever until keyboard break)")
parser.add_option("-d", "--delay", type = "int", action="store", dest="delay", default=1000, help="How often to query the sensor in ms (from 100 to 10000, defaults to 1000)")

(options, args) = parser.parse_args()
if options.bus == None:
	print("option -b is mandatory.")
	sys.exit()

if options.delay < 100 or options.delay > 10000:
	print("Invalid delay number! it should be 100 to 10000")
	sys.exit()

# Create sensor object, using the board's default I2C bus.
#i2c = board.I2C()  # uses board.SCL and board.SDA
#bme280 = adafruit_bme280.Adafruit_BME280_I2C(i2c)

# OR create sensor object, using the board's default SPI bus.
spi = board.SPI()

if options.bus == 0:
	bme_cs = digitalio.DigitalInOut(board.CE0)
else:
	bme_cs = digitalio.DigitalInOut(board.CE1)

bme280 = adafruit_bme280.Adafruit_BME280_SPI(spi, bme_cs)

# change this to match the location's pressure (hPa) at sea level
bme280.sea_level_pressure = 1013.25

for i in range(0, int(options.count)):
    print("\nTemperature: %0.1f C" % bme280.temperature)
    print("Humidity: %0.1f %%" % bme280.relative_humidity)
    print("Pressure: %0.1f hPa" % bme280.pressure)
    print("Altitude = %0.2f meters" % bme280.altitude)
    time.sleep(int(options.delay)/1000)
