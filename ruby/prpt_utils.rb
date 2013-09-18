#!/usr/bin/env ruby

require 'zip'
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

def get_meta(property, *prptfiles)
  prptfiles.each do |prptfile|
    puts "PRPT file: #{prptfile}"
    meta_doc = get_file_doc(prptfile, "meta.xml")
    property_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements[property]
    if not property_elem.nil?
      puts property_elem.text
    else
      puts ""
    end
  end
end

def set_meta(property, value, *prptfiles)
  prptfiles.each do |prptfile|
    meta_doc = get_file_doc(prptfile, "meta.xml")
    property_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements[property]

    if not title_elem.nil?
      print "Changing #{property} from #{title_elem.text}"
      property_elem.text = newtitle
      puts " to #{property_elem.text}"

      write_file_doc(prptfile, "meta.xml", meta_doc)
    end
  end
end

def get_layout(property, *prptfiles)
  puts "Running over these prpt files: #{prptfiles}"
  prptfiles.each do |prptfile|
    puts "PRPT file: #{prptfile}"
    meta_doc = get_file_doc(prptfile, "layout.xml")
    property_val = meta_doc.elements["layout"].attributes[property]

    puts property_val
  end
end

def set_layout(property, value, *prptfiles)
  prptfiles.each do |prptfile|
    meta_doc = get_file_doc(prptfile, "layout.xml")

    property_val = meta_doc.elements["layout"].attributes[property]
    print "Changing #{property} from #{property_val}"
    property_val = newtitle
    puts " to #{property_val}"

    write_file_doc(prptfile, "layout.xml", meta_doc)
    end
  end
end

def get_desc(prptfile)
  meta_doc = get_file_doc(prptfile, "meta.xml")
  title_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements['dc:desc']
  if not title_elem.nil?
    return title_elem.text
  else
    return ""
  end
end

def get_title(prptfile)
  meta_doc = get_file_doc(prptfile, "meta.xml")
  title_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements['dc:title']
  if not title_elem.nil?
    return title_elem.text
  else
    return ""
  end
end

def set_title(prptfile, newtitle)
  meta_doc = get_file_doc(prptfile, "meta.xml")
  title_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements['dc:title']

  if not title_elem.nil?
    print "Changing report title from #{title_elem.text}"
    title_elem.text = newtitle
    puts " to #{title_elem.text}"

    write_file_doc(prptfile, "meta.xml", meta_doc)
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
  layout_doc = get_file_doc(prptfile, "layout.xml")
  return layout_doc.elements["layout"].attributes[attribute]
end

def get_file_doc(prptfile, filename)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    return REXML::Document.new zipfile.read(filename)
  end
end

def write_file_doc(prptfile, filename, xmldoc)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    zipfile.get_output_stream(filename) do |zos|
      zos.write(xmldoc.to_s)
    end
  end
end

def handle_prpt(commands)
  # Argument binding: cmd is the first, then some potentially optional arguments
  cmd = commands.shift

  # Split on only the first '-'   The first part should be get or set, and the trailing component should be a property name
  dash_split = cmd.split('-', 2)

  property_map = {
    "title" => "meta:dc:title",
    "desc" => "meta:dc:description",
    "creator" => "meta:dc:creator",
    "subject" => "meta:dc:subject",
    "output-type" => "layout:core:preferred-output-type",
    "output-lock" => "layout:core:lock-preferred-output-type"
  }
  property = property_map[dash_split[1]]
  puts "property: #{property}", "Command: #{cmd}", "Dash_split: #{dash_split}"

  if not property.nil?
    # We're going to use command as a function-lookup. Start out with what should be either 'get' or 'set'
    command = dash_split[0]

    # The section is the first part specified in the property map; Currently either 'meta' or 'layout', which represent the meta or layout files in the zip-root
    section_split = property.split(':', 2)
    command += '_' + section_split[0]

    puts "Remaining Commands: #{commands}"
    # Section_split[1] contains the property value that we're interested in. Might be the subject, description, title, output, etc...
    # *commands expands all the remaining command-line arguments into the function call
    send(command, section_split[1], *commands)
  else
    # Fallback for when the command is not in the property map (either something a little more complex is happening, or we have no idea what they want
    puts <<-helpdoc
    prpt <COMMAND> [OPTIONS]

    COMMANDS:
        help          Show this usage doc
        extract-sql   extract all the queries from a report into the current directory
        get-title     Show the title of the report
        change-output change the report output type
        change-jndi   Change the JNDI connection name
    OPTIONS
        change-output <newtype> <report...>
        change-jndi   <newname> <report...>
    helpdoc
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
