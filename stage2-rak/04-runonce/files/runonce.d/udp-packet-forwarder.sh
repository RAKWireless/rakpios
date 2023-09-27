#!/bin/bash -e

# Load compressed image for the UDP packet forwarder
# NOTE: Images are loaded by the runonce script
#if [ -f /usr/local/share/docker-images/rakwireless_udp_packet_forwarder.tar ]; then 
#    docker load < /usr/local/share/docker-images/rakwireless_udp_packet_forwarder.tar
#fi

# Bring up service
docker compose -f /etc/local/runonce.d/udp-packet-forwarder.yml up -d

