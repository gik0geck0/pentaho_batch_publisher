#!/usr/bin/env ruby

# Set of functions that can be used to interface with a pentaho server
#
require 'rubygems'
require 'httparty'
require 'httmultiparty'
require 'digest/md5'
require 'io/console'


=begin
  FILE_EXISTS = 1;
  FILE_ADD_FAILED = 2;
  FILE_ADD_SUCCESSFUL = 3;
  FILE_ADD_INVALID_PUBLISH_PASSWORD = 4;
  FILE_ADD_INVALID_USER_CREDENTIALS = 5;
=end

class PentahoConnection

  def initialize(username, password, server='')
    @auth = { username: username, password: password }
    @server = server
  end

  public # public methods allow interfacing with the pentaho server with specific actions

  # Gets the XML representation of a pentaho server's solution repository
  def get_repo_xml()
    return get '/SolutionRepositoryService?component=getSolutionRepositoryDoc'
  end

  # Publish a list of prpts to the pentaho server
  def publish_report(files, path, pubpass, overwrite=true, mkdirs=false)
    params = {}
    # files should be a list of file names
    files.each do |f|
      puts "Filename: #{CGI::escape(f)}"
      openfile = File.new f, 'rb'
      params[URI.encode(f)] = openfile#.read #.encode(Encoding::UTF_8)
      #v = URI.escape(params[URI.encode(f)], Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      #openfile.close
    end
    path = CGI::escape(path)
    action_url = "/RepositoryFilePublisher?publishpath=#{path}&publishkey=#{get_passkey(pubpass)}&overwrite=#{overwrite}&mkdirs=#{mkdirs}"

    puts "Action url:", action_url
    return post action_url, params
  end

  def get_passkey(pubpass)
    m = Digest::MD5.new()
    m << pubpass
    m << "P3ntah0Publ1shPa55w0rd"
    return m.hexdigest
  end

  private # Conceal the raw http methods

  # use the HTTP get method on the supplied action
  def get(action, server=@server, auth=@auth )
    return HTTParty.get(action, basic_auth: auth, base_uri: server)
  end

  def post(action, params, server=@server, auth=@auth)
    query = params
    return HTTMultiParty.post(server+action, query: query, basic_auth: auth, base_uri: server)
  end

  def searchy(thingy)
    thingy.each do |thing| 
      if not thing.kind_of?(Array)
        puts "testing", thing
        puts "InQuery: #{thing}", URI.escape(thing, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      else
        searchy(thing)
      end
    end
  end

end

def handle_publish(commands)
  cmd = commands.shift
  server = commands.shift
#  puts "CMD: #{cmd}"
#  puts "Server: #{server}"

  if cmd != '--help' and !commands.include? '--help'
    print "Username for pentaho?"
    username = ''
    username = STDIN.gets.chomp
    puts "Username is #{username}"

    print 'Password:'
    password = STDIN.noecho(&:gets).chomp
    pconn = PentahoConnection.new username, password, server
  end

  if cmd == 'ls'
    puts pconn.get_repo_xml
  elsif cmd == 'file'
    print 'Publishing Password:'
    pubpass = STDIN.noecho(&:gets).chomp

    path = commands.shift
    # and the file list is the remainder
    files = commands

    puts "Publishing to server: #{server}, path: #{path}, file-list: #{files}"
    puts pconn.publish_report(files, path, pubpass)

  else
    puts <<-helpdoc
Usage:
publish <COMMAND> <server> [OPTIONS]"

Possible commands:
    ls      Show the solution repository (XML)
    help    Show this usage doc
    file    publish a file
OPTIONS
    For file command:
        publish [server] [path] [files...]
helpdoc

  end
end
