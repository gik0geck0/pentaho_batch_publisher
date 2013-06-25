#!/usr/bin/env python2

import paramiko

solution_dir = "/opt/pentaho/server/biserver-ee/pentaho-solutions"

# Program that will allow file transfer to a remote server via ssh, and allow the creation of folders with index files for pentaho use

create_folder(name, description, server):
    # open SSH connection
    ssh_conn = paramiko.SSHClient()
    ssh_conn.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    username = input("SSH Login as Username: ")
    password = input("Password: ")

    ssh_conn.connect(server, username=username, password=password)
    username = None
    password = None

    stdin, stdout, stderr = ssh_conn.execute_command("mkdir %s/%s" % (solution_dir,name))
    mkdir_out = stdout.readlines()
    if len(mkdir_out) > 0:
        print("Mkdir command has returned something:")
        for line in mkdir_out:
            print(line)

    # Add an index file in that newly created folder
    idx_file = "<?xml version='1.0' encoding='ISO-8859-1'?><index><name>%s</name><description>%s</description><icon>solutions.png</icon><visible>true</visible></index>" % (name, description)

    stdin, stdout, stderr = ssh_conn.execute_command("echo %s > %s/index.xml" % (idx_file, name))

