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

def change_run_type(prpt_file, new_type, custom_type=None):
    if new_type == 'csv':
        new_type = 'table/csv;page-mode=stream'
    elif new_type == 'pdf':
        new_type = 'pageable/pdf'
    elif new_type == 'xls':
        new_type = 'table/excel;page-mode=stream'
    elif new_type == 'custom' and custom_type != None:
        new_type = custom_type
    else:
        print("Unknown type")
        exit(1)

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

def sql_extractor(zipfile):
    readable_zip_file = ZipFile(zipfile, 'r')
    main_query_dom = mdom.parseString(readable_zip_file.read('datasources/sql-ds.xml'))
    all_queries = main_query_dom.getElementsByTagName('data:query')
    for element in all_queries:
        print(element.getAttribute('name'))
        for child in element.childNodes:
            #print(child.childNodes[0].nodeValue)
            out_sql = open(zipfile[:-5] + '-' + element.getAttribute('name') + '.sql', 'w')
            print("Child nodes:")
            print(child.childNodes)
            print(child.childNodes.nodeValue.strip())
            #out_sql.write(child.childNodes[0].nodeValue.strip())
            out_sql.close()
    readable_zip_file.close()

