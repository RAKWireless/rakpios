#!/usr/bin/env python3

import gpiod
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-r", "--read", action="append", nargs=2, type="int", dest="read", help="Read the specified line on the specified chip")
parser.add_option("-w", "--write", action="append", nargs=3, type="int", dest="write", help="Write the specified line on the specified chip")
parser.add_option("-l", "--list", action="append", nargs=1, type="int", dest="list", help="list all line status on the specified chip")

(options, args) = parser.parse_args()

if options.read:
    for element in options.read:
        chip_num = element[0]
        line_num = element[1]
        chip = gpiod.chip(chip_num)
        line = chip.get_line(line_num)
        config = gpiod.line_request()
        config.request_type = gpiod.line_request.DIRECTION_INPUT
        line.request(config)
        value = line.get_value()
        print("gpiochip%d line %d is: %d" % (chip_num, line_num, value))

if options.write:
    for element in options.write:
        chip_num = element[0]
        line_num = element[1]
        value = element[2]
        chip = gpiod.chip(chip_num)
        line = chip.get_line(line_num)
        config = gpiod.line_request()
        config.request_type = gpiod.line_request.DIRECTION_OUTPUT
        line.request(config)
        line.set_value(value)
        print("gpiochip%d line %d set to: %d" % (chip_num, line_num, value))

if options.list:
    chip_num = options.list[0]
    chip = gpiod.chip(chip_num)
    print("gpiodchip%d - %d lines:" % (chip_num, chip.num_lines))
    for i in range(0, chip.num_lines):
        line = chip.get_line(i)
        
        if line.name == "":
            name = "unnamed"
        else:
            name = line.name
            
        if line.is_used():
            use = "used"
        else:
            use = "unused"

        if line.direction == line.DIRECTION_INPUT:
            direction = "input"
        else:
            direction = "output"

        if line.active_state == line.ACTIVE_HIGH:
            active ="active-high"
        else:
            active = "active-low"
        print("    line %d:    %s    %s    %s    %s" %(i, name, use, direction, active))

