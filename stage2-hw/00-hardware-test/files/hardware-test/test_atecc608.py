#!/usr/bin/python3
from optparse import OptionParser
import sys
import board
import busio
from adafruit_atecc.adafruit_atecc import ATECC, _WAKE_CLK_FREQ
from adafruit_extended_bus import ExtendedI2C as I2C
import binascii


def print_serial():
    try:
        print("ATECC Serial: ", atecc.serial_number)
    except BaseException:
        print("Error output IC serial number")
        sys.exit()


def sha_calculation(string_to_cal):
    # Initialize the SHA256 calculation engine
    atecc.sha_start()
    atecc.sha_update(string_to_cal.encode('ascii'))

    # Return the digest of the data passed to sha_update
    message = atecc.sha_digest()
    # print("SHA Digest: ", message)
    print('SHA256 calculation result: ', (binascii.hexlify(bytearray(message))).decode('utf-8'))


parser = OptionParser()
parser.add_option("-b", "--bus", type="int", dest="bus",
                  help="I2C channel (0 or 1, defaults to 1) ")

parser.add_option("-s", "--serial", action="store_true", dest="serial", default=False,
                  help="Output the serial number of the IC")

parser.add_option("--sha256", type="str", dest="string",
                  help="Output the SHA256 of the input string,up to 64 bytes of data to be included into the hash operation.")
(options, args) = parser.parse_args()

# Define the default bus to use
ini_bus = 1

while isinstance(options.bus, int):
    if options.bus in range(0, 2):
        ini_bus = options.bus
        break
    else:
        print("Invalid bus value")
        sys.exit()

if ini_bus == 1:
    i2c = busio.I2C(board.SCL, board.SDA, frequency=_WAKE_CLK_FREQ)
elif ini_bus == 0:
    i2c = I2C(0, frequency=_WAKE_CLK_FREQ)

try:
    # Initialize a new atecc object
    atecc = ATECC(i2c)
except BaseException:
    print('Error: no I2C device at address: 0x60 on bus ' + str(ini_bus) + ', please check your i2c device')
    sys.exit()

if options.serial:
    print_serial()

if isinstance(options.string, str):
    try:
        sha_calculation(options.string)
    except BaseException:
        print("Error in string calculation")
        sys.exit()

