#!/usr/bin/python

import platform
import sys
import os
import glob
import subprocess

def execute_remotely(device):
    url = "https://raw.githubusercontent.com/pksteyn/php-fpmpal/master/php-fpmpal.01.sh"
    #cmd = "ot -C 'curl -s %s | python -' --sudo-make-me-a-sandwich %s" % (url, device)
    #cmd = "ht -C 'curl -s %s | bash -' --sudo-make-me-a-sandwich %s" % (url, device)
    cmd = "ht -C 'curl -s %s | bash' --sudo-make-me-a-sandwich %s" % (url, device)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, shell=True)
    output, err = p.communicate()
    if err:
        print err
    print output


def main():
    try:
        commandline_arg = sys.argv[1]
        if commandline_arg:
            execute_remotely(commandline_arg)
    except IndexError:
        display_output()

if __name__ == "__main__":
    main()

