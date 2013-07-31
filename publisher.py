#!/usr/bin/env python2

import sys
import paramiko
import getpass

solution_dir = "/opt/pentaho/server/biserver-ee/pentaho-solutions"

# Program that will allow file transfer to a remote server via ssh, and allow the creation of folders with index files for pentaho use

class Node(object):
    def __init__(self, data):
        self.data = data
        self.children = []

    def add_child(self, obj):
        self.children.append(obj)

def create_folder(name, description, server, username, password):
    # open SSH connection
    ssh_conn = paramiko.SSHClient()
    ssh_conn.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    ssh_conn.connect(server, username=username, password=password)

    stdin, stdout, stderr = ssh_conn.execute_command("mkdir %s/%s" % (solution_dir,name))
    mkdir_out = stdout.readlines()
    if len(mkdir_out) > 0:
        print("Mkdir command has returned something:")
        for line in mkdir_out:
            print(line)

    # Add an index file in that newly created folder
    idx_file = "<?xml version='1.0' encoding='ISO-8859-1'?><index><name>%s</name><description>%s</description><icon>solutions.png</icon><visible>true</visible></index>" % (name, description)

    stdin, stdout, stderr = ssh_conn.execute_command("echo %s > %s/index.xml" % (idx_file, name))

    ssh_conn.close()

def find_parent_node(root, child_tree_path):
    first_parent = root
    dir_components = child_tree_path.split('/')
    for c in root.children:
        if c.data == dir_components[0]:
            first_parent = c
            break
    if first_parent == root:
        if len(dir_components) > 1:
            # something went wrong. This child folder want's to belong to a parent that doesn't exist
            print("Error: Child folder is looking for its dead-beat parent")
            exit(1)
        else:
            # This folder is underneath the parent directly, and we don't want to recurse
            # This is also the end condition: We found the last parent that the child will belong to
            return first_parent

    else:
        # Recurse to the next level from this node
        return find_parent_node(first_parent, child_tree_path[len(dir_components[0])+1:])



# Return a Node object for the specified path, filled with all the files/directories below it
def get_directory_tree(server, username, password, path='/opt/pentaho/server/biserver-ee/pentaho-solutions', dir_only=True):
    print('Getting structure for path ' + path)
    my_node = Node(path.strip())

    ssh_conn = paramiko.SSHClient()
    ssh_conn.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    ssh_conn.connect(server, username=username, password=password)
    print('Login succeeded')

    # get all the files and directories
    stdin, stdout, stderr = ssh_conn.exec_command("find %s -mindepth 1" % (path))
    last_directory=my_node
    for line in stdout.readlines():
        line = line.strip()
        tree_name = line[len(path):]

        if not tree_name.startswith('/system') and not tree_name.startswith('/plugin-samples') and not tree_name.startswith('/admin') and not tree_name.startswith('/bi-developers') and not tree_name.startswith('/tmp'):
            print("Tree name: %s" % tree_name)
            base_name = tree_name[tree_name.rfind('/'):]
            # we're just goint to naively assume that all files without an extension are directories
            if base_name.find('.') == -1 or base_name.endswith('.prpt'):
                child_node = Node(base_name)

                if base_name.find('.') == -1:
                    print("%s is a directory" % tree_name)
                    # It's a directory
                    # When there's only one /, it's a directory in the root
                    if tree_name.count('/') == 1 or tree_name == last_directory.data + '/' + base_name:
                        print("Adding %s as an immediate sub-directory" % tree_name)
                        # This directory is a sub-directory
                        last_directory.children.append(child_node)
                    else:
                        # We need to backtrack to find out who this directory's parents are
                        print("Looking for the parents of %s" % tree_name)
                        parent = find_parent_node(my_node, tree_name)
                        parent.children.append(child_node)
                    last_directory = child_node
                else:
                    print("%s is a pentaho report file" % tree_name)
                    last_directory.children.append(child_node)
            else:
                print("%s is neither a directory nor a prpt" % tree_name)

                    
    ssh_conn.close()

    return my_node

def tree_bfs(tree, tabs=-1):
    print('Node: ' + tree.data)

    #tabs += 1
    #for node in tree.children:
    #    print('\t'*tabs + node.data)
    #for node in tree.children:
    #    if (len(node.children) > 0):
    #        tree_bfs(node, tabs)
    #tabs -= 1

def publish(prpt_file, server, username, password, directory):
    pass

import os
import xml.dom.minidom as mdom
from zipfile import *

def remove_file_from_zip(zipname, filename):
    os.rename(zipname, zipname + '.bak')
    old_in = ZipFile(zipname + '.bak', 'r')
    new_out = ZipFile(zipname, 'w')

    for item in old_in.infolist():
        buff = old_in.read(item)
        if item.filename != filename:
            new_out.writestr(item, buff)

    old_in.close()
    new_out.close()
    os.remove(zipname + '.bak')

def change_run_type(prpt_file, new_type):
    # Read the layout.xml into an XML DOM
    readable_zip_file = ZipFile(prpt_file, 'r')
    layout_dom = mdom.parseString(readable_zip_file.read('layout.xml'))
    readable_zip_file.close()

    # change the output-type to the new type
    layout_elements = layout_dom.getElementsByTagName('layout')
    if len(layout_elements) > 1:
        print("There was more than 1 layout tag in this layout file. Wtf mate?")
    print("Changing from type %s to the type %s" % (layout_elements[0].getAttribute('core:preferred-output-type'), new_type))
    layout_elements[0].setAttribute('core:preferred-output-type', new_type)

    # remove the old layout
    remove_file_from_zip(prpt_file, 'layout.xml')

    # write in the new layout
    writable_zip_file = ZipFile(prpt_file, 'a')
    writable_zip_file.writestr('layout.xml', layout_dom.toxml())

def query_output(zipfile):
    readable_zip_file = ZipFile(zipfile, 'r')
    output = mdom.parseString(readable_zip_file.read('layout.xml')).getElementsByTagName('layout')[0].getAttribute('core:preferred-output-type')
    readable_zip_file.close()
    return output


#username = str(raw_input("SSH Login as Username: "))
#password = getpass.getpass()
#dir_tree = get_directory_tree('localhost', username, password)

if sys.argv[2] == 'csv':
    new_type = 'table/csv;page-mode=stream'
elif sys.argv[2] == 'pdf':
    new_type = 'pageable/pdf'
elif sys.argv[2] == 'xls':
    new_type = 'table/excel;page-mode=stream'
elif sys.argv[2] == 'query':
    print(query_output(sys.argv[1]))
    exit(0)
else:
    print("Unknown type")
    exit(1)

change_run_type(sys.argv[1], new_type)

