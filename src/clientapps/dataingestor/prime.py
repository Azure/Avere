#!/usr/bin/env python
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
"""
~snider
mppopulate: 2m17
cat: 3m30 376226 73.13 GB
grep: 3m44 376226 73.13 GB
python: 20 376226 73.13 GB
"""

import os
import sys
import time
import multiprocessing
from collections import defaultdict
import optparse
import traceback
import subprocess

MEGABYTE = 2**20

parser = optparse.OptionParser(
    option_list = [
        optparse.Option('--directory', '-d', help='The directory to walk (default=%default)', default="."),
        optparse.Option('--workers', type='int', help="The number of workers (default=%default)", default=10),
        optparse.Option('--interval', type='int', help='If specified, how often (in seconds) to update with progress', default=0),
        ])
(options, args) = parser.parse_args()

directory = options.directory
print "Walking %s" % directory,
print "(using %s workers)" % options.workers

Data = {'files': 0,
        'size': 0,
        'fsize': 0,
}

SkipDirectories = ['.zfs', '.snapshot']

workers = options.workers

LastCheck = time.time()

def process_result(result):
    if not result:
        return

    for directory in result.get('dirs', []):
        r=Pool.apply_async(process_directory, args=[directory])
        Results[r] = directory

    Data['files'] += result['files']
    Data['size'] += result['size']
    if 'fsize' in result:
        Data['fsize'] += result['fsize']

    global LastCheck
    if options.interval and (time.time() - LastCheck) > options.interval:
        print time.ctime(),"primed %s files (%s)" % (Data['files'], bytes(Data['size']))
        LastCheck = time.time()

def count(c):
    mod = ""
    for mod in ["", "k", "M", "G", "T"]:
        if c > 1000:
            c /= 1000.0
        else:
            break
    return "%.2f%s" % (c, mod)

def bytes(size, convert=True):
    if convert:
        size = float(size)
    mod = ""
    for mod in ["", "KB", "MB", "GB", "TB", "PB"]:
        if size >= 1024:
            size /= 1024
        else:
            break
    if convert:
        return "%.2f %s" % (size,mod)
    else:
        return "%s %s" % (size,mod)

def readfile(incfilename):
    bytes = 0
    try:
        with open(incfilename, 'r') as f:
            while True:
                read = f.read(MEGABYTE)
                bytes += len(read)
                if not read:
                    break
    except:
        pass
    return bytes

def process_directory(directory):
    data = dict(dirs = [], files=0, size=0, fsize=0)
    try:
        entries = os.listdir(directory)
        for entry in entries:
            try:
                fentry = os.path.join(directory, entry)
                stat = os.lstat(fentry)
                if not os.path.islink(fentry) and os.path.isdir(fentry) and entry not in SkipDirectories:
                    data['dirs'].append(fentry)
                elif os.path.isfile(fentry) and not os.path.islink(fentry) and os.access(fentry, os.F_OK):
                    data['files'] += 1
                    data['size'] += stat.st_size
                    #                subprocess.call("grep -e '^NOTEXPECTEDTOFINDTHISINTHEFILE' '%s' >& /dev/null" % fentry, shell=True)
                    #                subprocess.call("cat '%s' >& /dev/null" % fentry, shell=True)
                    data['fsize'] += readfile(fentry)
            except:
                pass

    except Exception, e:
        print "fail"
        traceback.print_exc()
    return data

Pool = multiprocessing.Pool(workers)
Results = {}
r=Pool.apply_async(process_directory, args=[directory])
Results[r] = directory
while Results.keys():
    for r,d in Results.items():
        if not r.ready():
            continue
        process_result(r.get(timeout=1))
        del Results[r]
    time.sleep(.1)

Pool.close()
Pool.join()

print "Total files primed: %s" % count(Data['files'])
print "Total data primed: %s" % bytes(Data['size'])

