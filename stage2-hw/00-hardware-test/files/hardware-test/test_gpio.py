#!/usr/bin/python3

from optparse import OptionParser
import sys
import RPi.GPIO as GPIO


def board_to_gpio(num):
    numbers = {
        3: 2,
        5: 3,
        7: 4,
        8: 14,
        10: 15,
        11: 17,
        12: 18,
        13: 27,
        15: 22,
        16: 23,
        18: 24,
        19: 10,
        21: 9,
        22: 25,
        23: 11,
        24: 8,
        26: 7,
        27: 0,
        28: 1,
        29: 5,
        31: 6,
        32: 12,
        33: 13,
        35: 19,
        36: 16,
        37: 26,
        38: 20,
        40: 21
    }
    return numbers.get(num, None)


available_board_pin = {3, 5, 7, 8, 10, 11, 12, 13, 15, 16, 18, 19, 21, 22, 23, 24, 26, 27, 28, 29, 31, 32, 33, 35, 36,
                       37}


def read_one():
    GPIO.setup(read_port, GPIO.IN)
    override_to_default(read_port)

    if GPIO.input(read_port):
        print("GPIO " + str(read_port) + " input: 1")
    else:
        print("GPIO " + str(read_port) + " input: 0")
    override_to_default(read_port)
    print('Notice: Reading this port\'s input now, so there will be no output at this moment...')
    print('This port has been overridden to its default status')
    print('Check the Readme_test_GPIO.md file for more details')


def override_to_default(port_num):
    if port_num in range(0, 9):
        GPIO.setup(port_num, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    if port_num in range(9, 28):
        GPIO.setup(port_num, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
    return


def toggle_one():
    GPIO.setup(toggle_port, GPIO.IN)
    channel_is_on = GPIO.input(toggle_port)
    GPIO.setup(toggle_port, GPIO.OUT)
    if channel_is_on:
        GPIO.output(toggle_port, GPIO.LOW)
        print("This port was set to 1, now it should be set to 0...")
    else:
        GPIO.output(toggle_port, GPIO.HIGH)
        print("This port was set to 0, now it should be set to 1...")


def write_one():
    if write_value == 1:
        GPIO.setup(write_port, GPIO.OUT)
        GPIO.output(write_port, GPIO.HIGH)
        print("Turned on...")
    elif write_value == 0:
        GPIO.setup(write_port, GPIO.OUT)
        GPIO.output(write_port, GPIO.LOW)
        print("Turned off...")
    else:
        print("Invalid value to write")
        sys.exit()


def read_all():
    GPIO.setmode(GPIO.BCM)
    # Setup all GPIOs to input
    print("Use GPIO 2 to 27 as input and read GPIO input value...")
    for gpio in range(2, 28):
        GPIO.setup(gpio, GPIO.IN)
        print("GPIO no" + str(gpio) + ": " + str(GPIO.input(gpio)))
        override_to_default(gpio)


parser = OptionParser()
# Defines the options
parser.add_option("-g", action="store_true", dest="GPIO", default=False,
                  help="Interpret port number as BCM_GPIO rather than board pin numbers.")
parser.add_option("-r", "--read", type="int", dest="read",
                  help="Reads the specified port (port must be a valid port number)")
parser.add_option("-t", "--toggle", type="int", dest="toggle",
                  help="Toggles the specified port (port must be a valid port number)")
parser.add_option("-w", "--write", type="int", action="append", nargs=2, dest="write",
                  help="Toggles the specified port (port must be a valid port number, value must be 0 or 1)")
parser.add_option("-a", "--all", action="store_true", dest="all", default=False,
                  help="Reads and outputs all values")
(options, args) = parser.parse_args()

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

if options.GPIO:
    print("You are using BCM_GPIO numbering...")
    if isinstance(options.toggle, int):
        if options.toggle in range(0, 28):
            toggle_port = options.toggle
            toggle_one()
        else:
            print("Invalid BCM_GPIO port number")
            sys.exit()

    if isinstance(options.write, list):
        if (options.write[0])[0] in range(0, 28):
            write_port = (options.write[0])[0]
            write_value = (options.write[0])[1]
            write_one()
        else:
            print("Invalid BCM_GPIO port number")
            sys.exit()

    if isinstance(options.read, int):
        # if options.read in list(range(0, 2)) + list(range(4, 28)):
        if options.read in list(range(2, 28)):
            read_port = options.read
            read_one()
        else:
            print("Invalid BCM_GPIO port number")
            sys.exit()

else:
    print("You are using board pin numbering...")
    if isinstance(options.toggle, int):
        if options.toggle in available_board_pin:
            toggle_port = board_to_gpio(options.toggle)
            toggle_one()
        else:
            print("Invalid board pin number")
            sys.exit()

    if isinstance(options.write, list):
        if (options.write[0])[0] in available_board_pin:
            write_port = board_to_gpio((options.write[0])[0])
            write_value = (options.write[0])[1]
            write_one()
        else:
            print("Invalid board pin number")
            sys.exit()

    if isinstance(options.read, int):
        if options.read in available_board_pin:
            read_port = board_to_gpio(options.read)
            read_one()
        else:
            print("Invalid board pin number")
            sys.exit()

if options.all:
    read_all()
sys.exit()

