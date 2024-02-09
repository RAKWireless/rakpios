# RAKPiOS

Tool used to create RAKPiOS images based on pi-gen (https://github.com/RPI-Distro/pi-gen.git).

The RAKPiOS image differs from the stock Raspberry Pi OS in:

* Custom kernel with support for WiFi Next Gen AGN
* Overlays for existing components in RAK7391
* Docker installed by default
* Brings up a WiFi Access Point if no other connection is active
* Custom MOTD
* SSH, I2C and SPI enabled by default
* Set of utilities
  * OLED script to leverage a connected SSD1306 OLED screen to display system metrics
  * rakpios-cli to manage network and docker images
* Default user (`rak`) and password (`changeme`), forces user to create new password on first login

# Building

1. Edit and configure `config_rak` file.
2. Run docker builder:

    ` ./build-docker.sh -c config_rak`

3. Get the image from the deploy folder.

Check README at https://github.com/RPI-Distro/pi-gen.git for detailed instructions on the build process.

