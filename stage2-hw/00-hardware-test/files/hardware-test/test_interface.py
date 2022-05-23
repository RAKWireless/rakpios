#!/usr/bin/env python3
from statistics import mean
import iperf3
from optparse import OptionParser
import sys
import psutil
import subprocess
import json
import os
import signal

parser = OptionParser()
# Defines the options
parser.add_option("-i", "--interface", type="str", dest="iface",
                  help="Interface to test (should be one of the existing non-local interfaces, defaults to eth0)")

parser.add_option("-l", action="store_true", dest="list_iface", default=False,
                  help=" List all existing non-local interface (no \"lo\" interface or docker bridges)")

parser.add_option("-s", "--server", action="store_true", dest="server_mode", default=False,
                  help=" Server mode (listens to connections)")

parser.add_option("-c", "--client", type="str", dest="client_mode",
                  help="Client mode and server's address")

parser.add_option("-p", "--port", type="int", dest="port",
                  help="Port to use, defaults to 5201")

# parser.add_option("-r", "--protocol", type="str", dest="protocol",
#                   help="Protocol to use, Either \"UDP\" or \"TCP\", default to UDP")

parser.add_option("-m", "--mode", type="int", dest="mode",
                  help="0 for \"continuous\" mode and 1 for \"once\" mode." "Either \"continuous\" or \"once\" ("
                       "defaults to \"once\"). In \"continuous\" mode the script "
                       "should run until halted from the keyboard with Ctrl+C.In \"once\" mode the script will stop "
                       "after the default 10 seconds and output the speed results. "

                       "Only on the client side.")

(options, args) = parser.parse_args()

server_address = options.client_mode

client_address = options.iface
psutil.net_if_addrs()
net_status = psutil.net_if_addrs()


# For options -i
def bind_ip(iface_name):
    try:
        client_bind_address = net_status[iface_name][0][1]
        return client_bind_address
    except BaseException:
        print("Invalid interface name, try using options [-l] to list available interfaces")
        sys.exit()


# For options -l
def list_ip():
    try:
        del net_status['lo'], net_status['docker0']
    except BaseException:
        print("Missing interface lo and/or docker0,continue...")
    finally:
        for key, value in net_status.items():
            print('{0}      address: {1}'.format(key, value[0][1]))


# For options -s
def server_mode():
    server = iperf3.Server()
    server.verbose = False
    while True:
        server.run()


# For options -c
def client_mode():
    # print(get_mode(options.mode))
    if get_mode(options.mode) == 10:
        client = iperf3.Client()
        client.duration = get_mode(options.mode)
        client.server_hostname = server_address
        client.port = get_port(options.port)
        client.protocol = 'tcp'
        client.bind_address = bind_ip(options.iface)
        print('Connecting to {0}:{1}'.format(client.server_hostname, client.port))
        print('Enter once mode, the test will last for 10 seconds...')
        print(
            'Final test result will be displayed only after the test is finished, real-time data are displayed on the '
            'server')
        result = client.run()
        if result.error:
            print(result.error)
        else:
            #     if client.protocol == 'udp':
            #         print('')
            #         print('Test completed:')
            #         print('  started at                         {0}'.format(result.time))
            #         print('  Test duration in seconds           {0}'.format(result.duration))
            #         print('  protocol                           {0}'.format(result.protocol))
            #         print('  Lost packets (UDP client)          {0}'.format(result.lost_packets))
            #         print('  Lost percent (UDP client)          {0}'.format('%.2f' % (result.lost_percent * 100) + '%'))
            #         speed_list = []
            #         for i in result.json["intervals"]:
            #             speed_list.append(i["sum"]["bits_per_second"])
            #         print('  Max:                               {0}'.format('%.2f' % (max(speed_list) / 1000000)) + 'Mb/s')
            #         print('  Avg:                               {0}'.format('%.2f' % (mean(speed_list) / 1000000)) + 'Mb/s')
            #         print('  Min:                               {0}'.format('%.2f' % (min(speed_list) / 1000000)) + 'Mb/s')
            #     elif client.protocol == 'tcp':
            print('')
            print('Test completed:')
            print('  started at                         {0}'.format(result.time))
            print('  protocol                           {0}'.format(result.protocol))
            print('  Amount of retransmits (TCP client) {0}'.format(result.retransmits))
            print('  Test duration in seconds           {0}'.format(result.duration))
            speed_list = []
            for i in result.json["intervals"]:
                speed_list.append(i["sum"]["bits_per_second"])
            print('  Max:                               {0}'.format('%.2f' % (max(speed_list) / 1000000)) + 'Mb/s')
            print('  Avg:                               {0}'.format('%.2f' % (mean(speed_list) / 1000000)) + 'Mb/s')
            print('  Min:                               {0}'.format('%.2f' % (min(speed_list) / 1000000)) + 'Mb/s')
            # else:
            #     print("Invalid protocol")
            #     sys.exit()
    elif get_mode(options.mode) == 0:
        continuous_mode()

    else:
        print('invalid mode in function client_mode')


# For options -p
def get_port(server_port):
    server_port = 5201
    while isinstance(options.port, int):
        if options.port in range(0, 10000):
            server_port = options.port
            break
        else:
            print("Invalid port value")
            sys.exit()
    return server_port


# For server -r
# def get_protocol(protocol):
#     protocol = 'udp'
#     if isinstance(options.protocol, str):
#         if options.protocol == 'tcp':
#             protocol = 'tcp'
#     return protocol


# For option -m
def get_mode(duration):
    duration = 10
    if isinstance(options.mode, int):
        if options.mode == 1:
            duration = 10
        else:
            duration = 0
    return duration


def continuous_mode():
    print('Enter continuous mode, enter Ctrl + C to exit and check test result...')
    print(
        'Final test result will be displayed only after the test is finished, real-time data are displayed on the server')
    command_iface = '-B ' + bind_ip(options.iface) + ' '
    command_port = '-p ' + str(get_port(options.port)) + ' '
    command_server = '-c ' + str(server_address) + ' '
    command_duration = '-t inf '
    # print(str(get_protocol(options.protocol)))
    # if get_protocol(options.protocol) == 'udp':
    #     whole_command = 'iperf3 ' + command_iface + command_port + command_server + command_duration + '-u -b 2500M -l 64999 ' + '-J > iperf3_resut.json'
    #     print(whole_command)
    # elif get_protocol(options.protocol) == 'tcp':
    whole_command = 'iperf3 ' + command_iface + command_port + command_server + command_duration + '-J > iperf3_resut.json'
    # else:
    #     print('invalid mode')
    p = subprocess.Popen(whole_command, shell=True)
    try:
        p.wait()
    except KeyboardInterrupt:
        p.send_signal(signal.SIGINT)
        continuous_result()
        del_file()


def continuous_result():
    try:
        with open("iperf3_resut.json", 'r') as load_f:
            resultc = json.load(load_f)

        # if get_protocol(options.protocol) == 'udp':
        #     print('')
        #     print('Test completed:')
        #     print('  Test duration in seconds           {0}'.format('%.2f' % resultc['end']['sum']['seconds']))
        #     print('  protocol                           {0}'.format(resultc['start']['test_start']['protocol']))
        #     print('  Lost packets (UDP client)          {0}'.format(resultc['end']['sum']['lost_packets']))
        #     print('  Lost percent (UDP client)          {0}'.format(
        #         '%.2f' % (resultc['end']['sum']['lost_percent'] * 100) + '%'))
        #     speed_list = []
        #     for i in resultc["intervals"]:
        #         speed_list.append(i["sum"]["bits_per_second"])
        #     print('  Max:                               {0}'.format('%.2f' % (max(speed_list) / 1000000)) + 'Mb/s')
        #     print('  Avg:                               {0}'.format('%.2f' % (mean(speed_list) / 1000000)) + 'Mb/s')
        #     print('  Min:                               {0}'.format('%.2f' % (min(speed_list) / 1000000)) + 'Mb/s')
        #
        # elif get_protocol(options.protocol) == 'tcp':
        print('')
        print('Test completed:')
        print('  Test duration in seconds           {0}'.format('%.2f' % resultc['end']['sum_sent']['seconds']))
        print('  protocol                           {0}'.format(resultc['start']['test_start']['protocol']))
        print('  Amount of retransmits (TCP client) {0}'.format(resultc['end']['sum_sent']['retransmits']))
        speed_list = []
        for i in resultc["intervals"]:
            speed_list.append(i["sum"]["bits_per_second"])
        print('  Max:                               {0}'.format('%.2f' % (max(speed_list) / 1000000)) + 'Mb/s')
        print('  Avg:                               {0}'.format('%.2f' % (mean(speed_list) / 1000000)) + 'Mb/s')
        print('  Min:                               {0}'.format('%.2f' % (min(speed_list) / 1000000)) + 'Mb/s')
        # else:
        #     print("Invalid protocol")
        #     sys.exit()

    except BaseException:
        print('Error in reading json file, maybe the test last too short or too long?')
        # sys.exit()


def del_file():
    if os.path.exists('./iperf3_resut.json'):
        os.remove('iperf3_resut.json')
    else:
        print('iperf3_resut.json does not exist')


#####################################################
#####################################################
#####################################################
#####################################################
#####################################################
#####################################################


while isinstance(options.client_mode, str):
    client_mode()
    break

if options.list_iface:
    list_ip()

if options.server_mode:
    print('Enter server mode... press Ctrl + C to exit')
    while True:
        p_s = subprocess.Popen('iperf3 -s', shell=True).wait()

