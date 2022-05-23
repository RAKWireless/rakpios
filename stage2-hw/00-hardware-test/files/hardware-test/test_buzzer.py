#!/usr/bin/env python3
import gpiod
from optparse import OptionParser
import sys
import time

# Set default trigger GPIO value
buzzer_triggerPIN = 13
# Set Set default frequency value (Hz)
buzzer_frequency = 440
# Set default duration value (ms)
buzzer_duration = 1000

parser = OptionParser('python3 test_buzzer '+ '-g <port> -f <frequency> -d <duration>')
# Defines the options
parser.add_option("-g", "--port", type="int", dest="port",
                  help="GPIO as BCM_GPIO where the buzzer is connected to (defaults to 13,range is 0 to 27 )")
parser.add_option("-f", "--frequency", type="int", dest="frequency",
                  help="Frequency in hertz of the tone to generate (defaults to 440 Hz(A4), range is 10 to 5000 Hz)")
parser.add_option("-d", "--duration", type="int", dest="duration",
                  help="Duration in ms to play the tone (defaults to 1000 ms, range is 1 to 10000 ms)")
(options, args) = parser.parse_args()

# Update configurations for the buzzer and check for invalid values
while isinstance(options.port, int):
    if options.port in range(0, 28):
        buzzer_triggerPIN = options.port
        break
    else:
        print("Invalid BCM_GPIO port number")
        sys.exit()

while isinstance(options.frequency, int):
    if options.frequency in range(10, 5001):
        buzzer_frequency = options.frequency
        break
    else:
        print("Invalid frequency value")
        sys.exit()

while isinstance(options.duration, int):
    if options.duration in range(1, 10001):
        buzzer_duration = options.duration
        break
    else:
        print("Invalid duration value")
        sys.exit()

chip = gpiod.chip(0)
line = chip.get_line(buzzer_triggerPIN)
config = gpiod.line_request()
config.request_type = gpiod.line_request.DIRECTION_OUTPUT
line.request(config)

#simulate a PWM 
dutycycle = 0.5
base_time = 1 / buzzer_frequency
delay_on = base_time * dutycycle
delay_off = base_time * (1 - dutycycle) 
count = (buzzer_duration / 1000) / base_time

while count:
    line.set_value(1)
    time.sleep(delay_on)
    line.set_value(0)
    time.sleep(delay_off)
    count = count - 1
