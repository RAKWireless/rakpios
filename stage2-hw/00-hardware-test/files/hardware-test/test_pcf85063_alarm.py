#!/usr/bin/env python3
from optparse import OptionParser 
import smbus
import time
import datetime
import sys



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

def enableAlarm(): # datasheet 8.5.6.
     # check Table 2. Control_2
     control_2 = RTC_CTRL_2_DEFAULT | RTC_ALARM_AIE #enable interrupt
     control_2 &= ~RTC_ALARM_AF                     # clear alarm flag

     pcf85063.write_byte_data (address, RTC_CTRL_2, control_2)

def setAlarm (alarm_second, alarm_minute, alarm_hour, alarm_day, alarm_weekday):

     if (alarm_second < 99): # second
        alarm_second = constrain (alarm_second, 0, 59)
        alarm_second = decToBcd (alarm_second)
        alarm_second &= ~RTC_ALARM;
     else:
        alarm_second = 0x0
        alarm_second |= RTC_ALARM

     if (alarm_minute < 99): # minute
        alarm_minute = constrain (alarm_minute, 0, 59)
        alarm_minute = decToBcd (alarm_minute)
        alarm_minute &= ~RTC_ALARM
     else:
        alarm_minute = 0x0;
        alarm_minute |= RTC_ALARM

     if (alarm_hour < 99): #  hour
        alarm_hour = constrain(alarm_hour, 0, 23)
        alarm_hour = decToBcd(alarm_hour)
        alarm_hour &= ~RTC_ALARM
     else:
        alarm_hour = 0x0
        alarm_hour |= RTC_ALARM

     if (alarm_day < 99): # day
        alarm_day = constrain(alarm_day, 1, 31)
        alarm_day = decToBcd(alarm_day)
        alarm_day &= ~RTC_ALARM
     else:
        alarm_day = 0x0
        alarm_day |= RTC_ALARM

     if (alarm_weekday < 99): # weekday
        alarm_weekday = constrain(alarm_weekday, 0, 6)
        alarm_weekday = decToBcd(alarm_weekday)
        alarm_weekday &= ~RTC_ALARM
     else:
        alarm_weekday = 0x0
        alarm_weekday |= RTC_ALARM

     enableAlarm();

     pcf85063.write_byte_data (address, RTC_SECOND_ALARM, alarm_second)
     pcf85063.write_byte_data (address, RTC_MINUTE_ALARM, alarm_minute)
     pcf85063.write_byte_data (address, RTC_HOUR_ALARM,   alarm_hour)
     pcf85063.write_byte_data (address, RTC_DAY_ALARM,    alarm_day)
     #pcf85063.write_byte_data (address, RTC_WDAY_ALARM,   alarm_weekday)   # 0 for Sunday

def readAlarm():
     rdata = pcf85063.read_i2c_block_data (address, RTC_SECOND_ALARM, 5)    # datasheet 8.4.

     alarm_second = rdata[0]        # read RTC_SECOND_ALARM register

     if (RTC_ALARM & alarm_second): # check is AEN = 1 (second alarm disabled)
        alarm_second = 99           # using 99 as code for no alarm
     else:                          # else if AEN = 0 (second alarm enabled)
        alarm_second = bcdToDec (alarm_second & ~RTC_ALARM) # remove AEN flag and convert to dec number

     alarm_minute = rdata[1] # minute
     if (RTC_ALARM & alarm_minute):
        alarm_minute = 99
     else:
        alarm_minute = bcdToDec (alarm_minute & ~RTC_ALARM)

     alarm_hour = rdata[2] # hour
     if (RTC_ALARM & alarm_hour):
        alarm_hour = 99
     else:
        alarm_hour = bcdToDec (alarm_hour & 0x3F) # remove bits 7 & 6

     alarm_day = rdata[3] # day
     if (RTC_ALARM & alarm_day):
        alarm_day = 99
     else:
        alarm_day = bcdToDec (alarm_day & 0x3F) # remove bits 7 & 6

     alarm_weekday = rdata[4]  # weekday
     if (RTC_ALARM & alarm_weekday):
        alarm_weekday = 99
     else:
        alarm_weekday = bcdToDec (alarm_weekday & 0x07) # remove bits 7,6,5,4 & 3

     #print (alarm_day, alarm_hour, alarm_minute, alarm_second)
     print("set Alarm <day:%02d time:%02d:%02d:%02d> OK!"%(alarm_day, alarm_hour, alarm_minute, alarm_second))


usage = "./test_pcf85063_alarm [options]"
parser = OptionParser(usage=usage) 

parser.add_option("-a", "--address", type = "int", action="store", dest="address", default=0x51, help="Address of the pcf85063 in the bus (defaults to 0x51)")
parser.add_option("-b", "--bus", type = "int", action="store", dest="bus", default=1, help="I2C channel (defaults to 1)")
parser.add_option("-w", "--write", type = "string", action="store", dest="write", help="Set the datetime to the specified value <DDhhmmss> or <+ss>")

(options, args) = parser.parse_args()

if options.write == None:
    print("option -w is mandatory.")
    sys.exit()

# I2C-Adresse des PCF80063A
address = options.address
# Erzeugen einer I2C-Instanz und Öffnen des Busses
pcf85063 = smbus.SMBus(options.bus)

str = options.write
if len(str) < 8:
	second = int(str)
	timeArrary = time.localtime(time.time()+second)
	day = timeArrary.tm_mday
	hour = timeArrary.tm_hour
	minute = timeArrary.tm_min
	second = timeArrary.tm_sec
else:
	day = int(str[0:2])
	hour = int(str[2:4])
	minute = int(str[4:6])
	second = int(str[6:8])

if day < 0 or day > 31 or hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59:
	print("Error: wrong datetime formate.")
	sys.exit()

setAlarm (second, minute, hour, day, 4)
readAlarm()
