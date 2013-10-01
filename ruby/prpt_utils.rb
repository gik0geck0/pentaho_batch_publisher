#!/usr/bin/env ruby

require 'zip'
require 'rexml/document'

### Library-accessibility Functions ###

def get_title(prptfile)           return get_meta('dc:title', prptfile) end
def set_title(prptfile, newtitle) return set_meta('dc:title', newtitle, prptfile) end


def get_desc(prptfile)          return get_meta('dc:description', prptfile) end
def set_desc(prptfile, newval)  return set_meta('dc:description', newval, prptfile) end


def get_creator(prptfile)         return get_meta('dc:creator', prptfile) end
def set_creator(prptfile, newval) return set_meta('dc:creator', newval, prptfile) end

def get_subject(prptfile)         return get_meta('dc:subject', prptfile) end
def set_subject(prptfile, newval) return set_meta('dc:subject', newval, prptfile) end


def get_output_type(prptfile)       return get_layout('core:preferred-output-type', prptfile) end
def set_output_type(prptfile, type) return set_layout('core:preferred-output-type', type, prptfile) end


def get_output_lock(prptfile)       return get_layout('core:lock-preferred-output-type', prptfile) end
def set_output_lock(prptfile, lock) return set_layout("core:lock-preferred-output-type", lock, prptfile) end


### Core-functionality ###

# Show the value of a property in the meta file of a report
# This function currently uses the XML-branch: office:document-meta -> office:meta # property
def get_meta(property, prptfile)
  meta_doc = get_file_doc(prptfile, "meta.xml")
  property_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements[property]

  if not property_elem.nil?
    return property_elem.text
  else
    return ""
  end
end

# Change the value of a property in the meta file of a report
# This function currently uses the XML-branch: office:document-meta -> office:meta # property
def set_meta(property, newvalue, prptfile)
  currentval = get_meta(property, prptfile)

  meta_doc = get_file_doc(prptfile, "meta.xml")

  property_elem = meta_doc.elements['office:document-meta'].elements['office:meta'].elements[property]
  if not property_elem.nil?
    property_elem.text = newvalue
  else
    property_eleme = newvalue
  end

  write_file_doc(prptfile, "meta.xml", meta_doc)

  return "Changed '#{currentval}' to '#{newvalue}'"
end

# Show the currenty value for a property in the layout file of a report
def get_layout(property, prptfile)
  meta_doc = get_file_doc(prptfile, "layout.xml")
  property_val = meta_doc.elements["layout"].attributes[property]

  if not property_val.nil?
    return property_val
  else
    return ""
  end
end

# Set a property in the layout file of a report
def set_layout(property, newvalue, prptfile)
  currentval = get_layout(property, prptfile)

  meta_doc = get_file_doc(prptfile, "layout.xml")
  meta_doc.elements["layout"].attributes[property] = newvalue
  write_file_doc(prptfile, "layout.xml", meta_doc)

  return "Changed '#{currentval}' to '#{newvalue}'"
end

# Go through all the queries and subreports, and set the jndi name
def set_jndi_names(prptfile, new_jndi_name)
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

# Show the names of all the JNDI connections in the report. This will be shown per-query
def get_jndi_names(prptfile)
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

# Get a file in the root of the supplied report
def get_file_doc(prptfile, filename)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    return REXML::Document.new zipfile.read(filename)
  end
end

# Write the given xmldocument to a file in the report
# xmldoc is expected to be an REXML object
def write_file_doc(prptfile, filename, xmldoc)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    zipfile.get_output_stream(filename) do |zos|
      zos.write(xmldoc.to_s)
    end
  end
end

# TODO: Finish implementing
# In the future, this function will extract all the sql for a pentaho report into
# a directory, with one .sql file per query. The name of the files will be based off
# the names of the queries
def extract_sql(prptfile)
  Zip::ZipFile.open(prptfile, Zip::ZipFile::CREATE) do |zipfile|
    #subreports = REXML::Document.new zipfile.read("layout.xml")
    #doc.elements["layout"].attributes[attribute] = newvalue
    zipfile.each do |file|
      puts file
    end
  end
end


### Main and Output ###

def list_output(*args)
  puts <<-OUTPUTDOC
Report Output-types:
    pageable/pdf
    table/csv;page-mode=stream
    table/excel;page-mode=flow
    table/html;page-mode=page
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;page-mode=flow
  OUTPUTDOC
end

def handle_prpt(commands)
  # Argument binding: cmd is the first, then some potentially optional arguments
  command = commands.shift

  # Split on only the first '-'   The first part should be get or set, and the trailing component should be a property name
  #dash_split = cmd.split('-', 2)

  property_map = {
    "title" => "meta:dc:title",
    "desc" => "meta:dc:description",
    "creator" => "meta:dc:creator",
    "subject" => "meta:dc:subject",
    "output-type" => "layout:core:preferred-output-type",
    "output-lock" => "layout:core:lock-preferred-output-type",
    "jndi" => "jndi_names"
  }
  target = commands.shift
  property = property_map[target]

  if not property.nil?
    # We're going to use command as a function-lookup. Start out with what should be either 'get' or 'set'
    func_name = command

    # The section is the first part specified in the property map; Currently either 'meta' or 'layout', which represent the meta or layout files in the zip-root
    section_split = property.split(':', 2)
    func_name += '_' + section_split[0]

    if command == 'set'
      newval = commands.shift
    end

    file_property = section_split[1]
    commands.each do |file|
      # file_property contains the property value that we're interested in. Might be the subject, description, title, output, etc...
      # *commands expands all the remaining command-line arguments into the function call
      args = [file_property]
      if not newval.nil?
        args << newval
      end
      args << file

      puts send(func_name, *args)
    end

  else
    # Fallback for when the command is not in the property map. Most likely, we have no idea what the user wants.

    puts <<-helpdoc

prpt <COMMAND> [OPTIONS]

COMMANDS:
    help            Show this usage doc
    list-output     Display all the current pentaho output types
    extract-sql     extract all the queries from a report into the current directory
    get             Show a property of one or more reports
    set             Set a property of one or more report

OPTIONS
    set   <property> <newvalue> <reports...>
    get   <property> <reports...>

Report Properties
    title           Title of the Report
    desc            Detailed description
    creator         User who created the report
    subject         Subject of the report
    output-type     Output format
    output-lock
    jndi

    helpdoc

    list_output()
  end
end
