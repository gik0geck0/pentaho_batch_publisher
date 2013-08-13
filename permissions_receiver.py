#!/usr/bin/env python2

import signal
import os

def change_permissions(sig_num, stack_frame):
    #path = '/opt/pentaho/server/biserver-ee/pentaho-solutions'
    print("Received USR1 Signal")
    path = '/home/mattbuland/test_dir'
    os.chmod(path, 0777)
    for dirname, dirnames, filenames in os.walk(path):
        for f in filenames:
            os.chmod(dirname + '/' + f, 0777)
        for d in dirnames:
            os.chmod(dirname + '/' + d, 0777)

signal.signal(signal.SIGUSR1, change_permissions)
while True:
    signal.pause()
