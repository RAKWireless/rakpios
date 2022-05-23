#!/usr/bin/env python3
from optparse import OptionParser
from luma.core.interface.serial import i2c
from luma.oled.device import ssd1306, ssd1331, sh1106
from luma.core.render import canvas

from pathlib import Path
from PIL import Image
import sys


usage = "./test_ssd1306 [options] [demo]\n\nArguments:\n[demo]	Demo to run,set 1 will dispaly a text 'hello,world', 2 will dispaly pi logo image"
parser = OptionParser(usage=usage) 

parser.add_option("-a", "--address", action="store", dest="address", default=0x3C, help="Address of the STTS751 in the bus (defaults to 0x3C)")
parser.add_option("-b", "--bus", action="store", dest="bus", default=1, help="I2C channel (defaults to 1)")

(options, args) = parser.parse_args()

addr = options.address
port = options.bus

if len(args) == 0:
	print("Error: argument 'demo' is mandatory")
	sys.exit()
demo = int(args[0])

# rev.1 users set port=0
# substitute spi(device=0, port=0) below if using that interface
serial = i2c(port=port, address=addr)

# substitute ssd1331(...) or sh1106(...) below if using that device
device = ssd1306(serial)

if demo == 1:
	try:
		while True:
			with canvas(device) as draw:
				draw.rectangle(device.bounding_box, outline="white", fill="black")
				draw.text((30, 40), "Hello World", fill="white")
	except KeyboardInterrupt:
		pass
		
elif demo == 2:
	try:
		img_path = str(Path(__file__).resolve().parent.joinpath('images', 'pi_logo.png'))
		logo = Image.open(img_path).convert("RGBA")
		fff = Image.new(logo.mode, logo.size, (255,) * 4)

		background = Image.new("RGBA", device.size, "white")
		posn = ((device.width - logo.width) // 2, 0)

		while True:
			for angle in range(0, 360, 2):
				rot = logo.rotate(angle, resample=Image.Resampling.BILINEAR)
				img = Image.composite(rot, fff, rot)
				background.paste(img, posn)
				device.display(background.convert(device.mode))
	except KeyboardInterrupt:
		pass
else:
	print("Invalid demo number!")
