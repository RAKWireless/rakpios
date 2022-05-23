# Hardware Test

packages/libraries required for each test:

test_buzzer:  sudo pip3 install RPi.GPIO
 
## GPIO specific

Import notice:

After you set a port to output and then decided to read the input value of this port, the testing script will automatically set this port to it's default status. And that's the reason why you will see the port you 
are testing stops to output when you use -r [port] to read the input. 

The reason is if you do not have the input pin connected to anything, it will 'float'. In other words, the value that is read in is undefined because it is not connected to anything until you press a button or switch.
To get round this, users need to have pull up/down resistors in hardware or just use software, in our case, we use the RPI.GPIO module, which allows you to configure the Broadcom SOC to do this in software.

if you have set your GPIOs to output mode, and then to input, chances are that you’re going to read 1 (HIGH) for all GPIOs, unless reboot your Pi. RPI.GPIO's built-in GPIO.cleanup() function works on Raspberry pi 3b+, but not on
Raspberry Pi 4B and CM4, that's why we created a function called override_to_default to help us reset the port's status to avoid the "read 1 for all GPIOs" issue.

## Dying gasp test

Use ./dying_gasp.py to start the test. 
After test is finished (powered off and then booted again), use cat/nano/vim to view the log,
for example :  
cat log_dying_gasp_20220127-095108.log
