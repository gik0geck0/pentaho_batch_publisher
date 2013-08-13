#!/usr/bin/env ruby

# Set of functions that can be used to interface with a pentaho server
#
require 'rubygems'
require 'httparty'
require 'httmultiparty'
require 'digest/md5'

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
    action_url = "/RepositoryFilePublisher?publishPath=#{path}&publishKey=#{get_passkey(pubpass)}&overwrite=#{overwrite}&mkdirs=#{mkdirs}"

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
    query = params#.merge({ basic_auth: auth, base_uri: server })
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

pconn = PentahoConnection.new '', ''

puts pconn.publish_report([''], '', '')
#puts pconn.get_repo_xml
