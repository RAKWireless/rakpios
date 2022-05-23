#!/usr/bin/env python3

from optparse import OptionParser 
import smbus
import time
import datetime
import random

# registar overview - crtl & status reg
RTC_CTRL_1 = 0x00
RTC_CTRL_2 = 0x01
RTC_OFFSET = 0x02
RTC_RAM_by = 0x03

# registar overview - time & data reg
RTC_SECOND_ADDR = 0x04
RTC_MINUTE_ADDR = 0x05
RTC_HOUR_ADDR   = 0x06
RTC_DAY_ADDR    = 0x07
RTC_WDAY_ADDR   = 0x08
RTC_MONTH_ADDR  = 0x09
RTC_YEAR_ADDR	= 0x0a # years 0-99; calculate real year = 1970 + RCC reg year

# registar overview - alarm reg
RTC_SECOND_ALARM = 0x0b
RTC_MINUTE_ALARM = 0x0c
RTC_HOUR_ALARM   = 0x0d
RTC_DAY_ALARM    = 0x0e
RTC_WDAY_ALARM   = 0x0f

# registar overview - timer reg
RTC_TIMER_VAL   = 0x10
RTC_TIMER_MODE  = 0x11
RTC_TIMER_TCF   = 0x08
RTC_TIMER_TE    = 0x04
RTC_TIMER_TIE   = 0x02
RTC_TIMER_TI_TP = 0x01

# format
RTC_ALARM          = 0x80	# set AEN_x registers
RTC_ALARM_AIE      = 0x80	# set AIE ; enable/disable interrupt output pin
RTC_ALARM_AF       = 0x40	# set AF register ; alarm flag needs to be cleared for alarm
RTC_CTRL_2_DEFAULT = 0x00
RTC_TIMER_FLAG     = 0x08

TIMER_CLOCK_4096HZ   = 0
TIMER_CLOCK_64HZ     = 1
TIMER_CLOCK_1HZ      = 2
TIMER_CLOCK_1PER60HZ = 3

def decToBcd(val):
     return ((val // 10 * 16) + (val % 10))

def bcdToDec(val):
     return ((val // 16 * 10) + (val % 16))

def constrain (val, min_val, max_val):
    return min (max_val, max(min_val, val))

def reset():	# datasheet 8.2.1.3.
	pcf85063.write_byte_data (address, RTC_CTRL_1, 0x58)

def setTime (hour, minute, second):
	pcf85063.write_byte_data (address, RTC_SECOND_ADDR, decToBcd(second))
	pcf85063.write_byte_data (address, RTC_MINUTE_ADDR, decToBcd(minute))
	pcf85063.write_byte_data (address, RTC_HOUR_ADDR, decToBcd(hour))


def setDate (day, month, yr):

	year = yr - 1970; 	# convert to RTC year format 0-99
	pcf85063.write_byte_data (address, RTC_DAY_ADDR,   decToBcd(day))
	#pcf85063.write_byte_data (address, RTC_WDAY_ADDR,  decToBcd(weekday))   # 0 for Sunday
	pcf85063.write_byte_data (address, RTC_MONTH_ADDR, decToBcd(month))
	pcf85063.write_byte_data (address, RTC_YEAR_ADDR,  decToBcd(year))

def readTime():
	rdata = pcf85063.read_i2c_block_data (address, RTC_SECOND_ADDR, 7)
	#print (rdata)

	#print (bcdToDec (rdata[0] & 0x7f)) # second
	#print (bcdToDec (rdata[1])& 0x7f)  # minute
	#print (bcdToDec (rdata[2] & 0x3f)) # hour

	#print (bcdToDec (rdata[3] & 0x3f)) # day
	#print (bcdToDec (rdata[4] & 0x07)) # wday
	#print (bcdToDec (rdata[5] & 0x1f)) # month
	#print (bcdToDec (rdata[6]) + 1970) # year
	print("%d-%02d-%02d %02d:%02d:%02d" %(bcdToDec(rdata[6]) + 1970, bcdToDec(rdata[5] & 0x1f), bcdToDec(rdata[3] & 0x3f), bcdToDec(rdata[2] & 0x3f), bcdToDec(rdata[1] & 0x7f), bcdToDec(rdata[0] & 0x7f)))

usage = "./test_pcf85063_random [options]"
parser = OptionParser(usage=usage) 

parser.add_option("-a", "--address", type = "int", action="store", dest="address", default=0x51, help="Address of the pcf85063 in the bus (defaults to 0x51)")
parser.add_option("-b", "--bus", type = "int", action="store", dest="bus", default=1, help="I2C channel (defaults to 1)")
parser.add_option("-c", "--count", type = "int", action="store", dest="count", default=1, help="How many times to test the RTC (defaults to 1, 0 means forever until keyboard break)")
parser.add_option("-d", "--delay", type = "int", action="store", dest="delay", default=0, help="Delay in ms between writing and reading the time (any natural number, defaults to 0 which means 'read right after write')")

(options, args) = parser.parse_args()

# I2C-Adresse des PCF80063A
address = options.address
# Erzeugen einer I2C-Instanz und Öffnen des Busses
pcf85063 = smbus.SMBus(options.bus)

for i in range(0, int(options.count)):
	yr = random.randint(1970, 2099)
	month = random.randint(1, 12)
	day = random.randint(1, 31)
	hour = random.randint(1, 24)
	minute = random.randint(1, 60)
	second = random.randint(1, 60)
	setTime (hour, minute, second)
	setDate (day, month, yr)
	print("set  Time: %d-%02d-%02d %02d:%02d:%02d" % (yr, month, day, hour, minute, second))
	time.sleep(options.delay/1000)
	print("read Time:",end=" ")
	readTime ()
