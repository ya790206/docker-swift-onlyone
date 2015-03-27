#!/usr/bin/env python
import os
from swift.common.ring import Ring
import sys
import json
from swift.common.utils import hash_path, storage_directory

ACCOUNT = 'AUTH_test'


class MyEncoder(json.JSONEncoder):
    def default(self, obj):
        try:
            return json.JSONEncoder.default(self, obj)
        except:
            return str(obj)


def pretty_print(obj):
    print(json.dumps(obj, sort_keys=True, indent=4, separators=(',', ': '), cls=MyEncoder, skipkeys=True))


def get_request():
    if len(sys.argv) == 3:
        return 'object', sys.argv[1:]
    elif len(sys.argv) == 2:
        return 'container', sys.argv[1:]
    else:
        print sys.argv



def get_path(ring, args):
    name_hash = hash_path('AUTH_test', *args)
    partition = ring.get_part(*args)
    ret = []
    nodes = ring.get_nodes(ACCOUNT, *args)[1]
    devices = [i['device'] for i in nodes]
    for device in devices:
        ret.append(storage_directory(device, partition, name_hash))
    return ret

if __name__ == '__main__':
    ring_name, args = get_request()
    ring = Ring('/etc/swift', ring_name=ring_name)
    for i in get_path(ring, args):
        print i

