#!/usr/bin/env python3
import gpiod
import subprocess
import time
from datetime import timedelta,datetime

POWER_GPIO = 16

def power_unplugged():
    # notify to all consoles that the power supply has been removed
    subprocess.run("wall Power unplugged,start time logging,please check log_dying_gasp.log for test result",
                   shell=True)
    # Start logging to a file in a persistent partition
    log = 'log_dying_gasp_' + time.strftime("%Y%m%d-%H%M%S") + '.log'
    duration_unplugged = 0
    while True:
        system_time = datetime.now().strftime('%Y%m%d_%H:%M:%S - ')
        with open(log, 'w') as logfile:
            logfile.write(system_time + str(duration_unplugged) + ' seconds after power unplugged' + '\n')
        time.sleep(0.5)  # log the time with a frequency of 2Hz
        duration_unplugged += 0.5


if __name__ == '__main__':
    print("After power unplugged is detected, this script will send a notification and then start to log the time.")
    print("The log will be created in the same directory, saved persistently (will overwrite previous log if the "
          "script is "
          "executed again.")
    
    chip = gpiod.chip(0)
    line = chip.get_line(POWER_GPIO)
    config = gpiod.line_request()
    config.request_type = gpiod.line_request.EVENT_FALLING_EDGE
    line.request(config)

    while True:
        if line.event_wait(timedelta(seconds=0.1)):
            event = line.event_read()
            if event.event_type == gpiod.line_event.FALLING_EDGE:
                power_unplugged()

