#!/usr/bin/env ruby

require 'zip/zip'
require 'rexml/document'

def extract_sql(prptfile)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    #subreports = REXML::Document.new zipfile.read("layout.xml")
    #doc.elements["layout"].attributes[attribute] = newvalue
    zipfile.each do |file|
      puts file
    end
  end
end

# go through all the queries and subreports, and change the jndi name
def change_jndi_name(prptfile, new_jndi_name)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    #doc.elements["layout"].attributes[attribute] = newvalue
    zipfile.each do |file|
      if file.name.end_with?('sql-ds.xml')
        datasource = REXML::Document.new zipfile.read(file)
        jndi_definition = datasource.elements['data:sql-datasource'].elements['data:jndi']
        if not jndi_definition.nil?
          data_path = jndi_definition.elements['data:path']
          print "Changing jndi name from #{data_path.get_text}"
          data_path.text= new_jndi_name
          puts " to #{data_path.get_text}"

          zipfile.get_output_stream(file) do |zos|
            zos.write(datasource.to_s)
          end
        end
      end
    end
  end
end

def print_jndi_names(prptfile)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    #doc.elements["layout"].attributes[attribute] = newvalue
    zipfile.each do |file|
      if file.name.end_with?('sql-ds.xml')
        datasource = REXML::Document.new zipfile.read(file)
        jndi_definition = datasource.elements['data:sql-datasource'].elements['data:jndi']
        if not jndi_definition.nil?
          data_path = jndi_definition.elements['data:path']
          puts "JNDI Connection: #{data_path.get_text}"
        end
      end
    end
  end
end

def change_lockoutput(prptfile, lock)
  change_layout_attribute(prptfile, "core:lock-preferred-output-type", lock)
end

def change_output_type(prptfile, type)
  #puts "Previous output type: #{get_layout_attribute(prptfile, 'core:preferred-output-type')}"
  change_layout_attribute(prptfile, 'core:preferred-output-type', type)
  #puts "New output type: #{get_layout_attribute(prptfile, 'core:preferred-output-type')}"
end

def change_layout_attribute(prptfile, attribute, newvalue)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    doc = REXML::Document.new zipfile.read("layout.xml")
    doc.elements["layout"].attributes[attribute] = newvalue

    zipfile.get_output_stream('layout.xml') do |zos|
      zos.write(doc.to_s)
    end
  end
end

def get_layout_attribute(prptfile, attribute)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    return doc.elements["layout"].attributes[attribute]
  end
end

def handle_prpt(commands)
  cmd = commands.shift


  if cmd =='change-output'
    newtype = commands.shift
    puts change_output_type(commands.shift, newtype)
  elsif cmd == 'extract-sql'
    extract_sql(commands.shift)
  elsif cmd == 'change-jndi'
    newname = commands.shift
    commands.each do |prpt|
      change_jndi_name(prpt, newname)
    end
  elsif cmd == 'get-jndi'
    commands.each do |prpt|
      print_jndi_names(prpt)
    end
  else
      puts <<-helpdoc
  prpt <COMMAND> [OPTIONS]

  COMMANDS:
      help          Show this usage doc
      extract-sql   extract all the queries from a report into the current directory
      change-output change the report output type
      change-jndi   Change the JNDI connection name
  OPTIONS
      change-output <newtype> <report...>
      change-jndi   <newname> <report...>
  helpdoc
    if cmd != 'help'
      puts '',"I'm sorry Dave, I'm afraid I can't do that."
    end
  end
end

=begin
Python code used to modify PRPTs

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
=end
