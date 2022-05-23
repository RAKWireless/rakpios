#!/usr/bin/env python3
import smbus2
import time
import sys
from optparse import OptionParser

_address = 0x50

class CAT24C32:
    def __init__(self, bus=1):
        self._bus = smbus2.SMBus(bus)

    def write(self, register_address, data):
        data = list(register_address.to_bytes(2, "big")) + data
        msg = smbus2.i2c_msg.write(_address, data)

        try:
            self._bus.i2c_rdwr(msg)
            return
        except OSError as e:
            if e.errno == 121: # Remote I/O error aka slave NAK
                pass

        time.sleep(0.005)
        self._bus.i2c_rdwr(msg)

    def read(self, register_address, length=1):
        self.write(register_address, [])
        msg = smbus2.i2c_msg.read(_address, length)
        self._bus.i2c_rdwr(msg)
        data = list(msg)
        return data

usage = "./test_eeprom [options] [address] <[address]>"
parser = OptionParser(usage=usage)

parser.add_option("-a", "--address", type = "int", action="store", dest="address", default=0x50, help="Address of the CAT24C32 in the bus (defaults to 0x50)")
parser.add_option("-b", "--bus", type = "int", action="store", dest="bus", default=1, help="I2C channel (0 or 1,defaults to 1)")
parser.add_option("-r", "--read", action="store_true", dest="read", help="read value from assign address ")
parser.add_option("-w", "--write", type="int", action="append", nargs=2, dest="write", help="write value to assign address")


(options, args) = parser.parse_args()

addr = options.address
bus = options.bus

if isinstance(options.write, list):
    addr = (options.write[0])[0]
    data = (options.write[0])[1]
    value = []
    value.append(data)
    eeprom = CAT24C32()
    eeprom.write(addr, value)
    sys.exit()

if options.read == True:


    if len(args) == 0:
        print("argument 'address' is mandatory")

    elif len(args) == 1:
	    addr1 = int(args[0])
	    eeprom = CAT24C32()
	    data = eeprom.read(addr1, 1)
	    print(data[0])

    elif len(args) == 2:
	    addr1 = int(args[0])
	    addr2 = int(args[1])
	    if addr1 > addr2:
		    print("second address should be bigger than first one.")
		    sys.exit()
	    eeprom = CAT24C32()
	    data = eeprom.read(addr1, length=addr2 -addr1 +1)
	    print(end="        ")
	    for x in range(0,8):
		    print("%2d" % x,end="   ")
	    print("")

	    for y in range(0, addr2+1):
		    if y%8 == 0:
			    print("0x%02x" % y,end="    ")
		    if y < addr1:
			    print(end="     ")
		    else:
			    print("%2d" % data[y - addr1],end="   ")
		    if (y+1)%8 == 0:
			    print("")
    else:
	    print("invalid argument number. ")
	    sys.exit()
else:
    print("invalid argument. ")
