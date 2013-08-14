#!/usr/bin/env python3

import urllib.request
from http.client import HTTPSConnection
from base64 import b64encode
import getpass
import sys

def get_repository_xml(server, username, password):
    action = '/SolutionRepositoryService?component=getSolutionRepositoryDoc'

    h = HTTPSConnection(server)
    userAndPass = b64encode(b"%s:%s" % (username, password)).decode("ascii")
    headers = { 'Authorization' : 'Basic %s' % userAndPass }
    
    h.request('GET', action, headers=headers)

    resp = h.getresponse()
    data = resp.read()

    return data

if sys.argv[2] in ('csv', 'pdf', 'xls', 'custom'):
    change_run_type(sys.argv[1], sys.argv[2], ('--lock=false' not in sys.argv), None if sys.argv[3].startswith('--') else sys.argv[3])
elif sys.argv[2] == 'query':
    print(query_output(sys.argv[1]))
elif sys.argv[2] == 'sql':
    sql_extractor(sys.argv[1])
elif sys.argv[2] == 'publish':
    username = str(raw_input("SSH Login as Username: "))
    password = getpass.getpass()
    publish(sys.argv[1], sys.argv[3], username, password, sys.argv[4])
elif sys.argv[2] == 'list':
    show_directory_tree('localhost', username, password)
elif sys.argv[2] == 'ls':
    username = str(input("Pentaho Login as Username: "))
    password = getpass.getpass()
    print(get_repository_xml(sys.argv[3], username, password))
