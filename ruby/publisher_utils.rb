#!/usr/bin/env ruby

# Set of functions that can be used to interface with a pentaho server
#
require 'rubygems'
require 'httparty'
require 'httmultiparty'
require 'digest/md5'
require 'io/console'
require 'pp'
require 'terminal-table'
require_relative 'prpt_utils'


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

  # Gets the hash representation of a pentaho server's solution repository
  def get_repo_hash
    return get '/SolutionRepositoryService?component=getSolutionRepositoryDoc'
  end

  def get_pub_pass
    print 'Publishing Password:'
    return STDIN.noecho(&:gets).chomp
  end

  # Publish a list of prpts to the pentaho server
  def publish_report(files, path, pubpass=get_pub_pass(), overwrite=true, mkdirs=false)

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

    #puts "Action url:", action_url
    return post action_url, params
  end

  # Starting at a certain node, recurse through the file-paths, and get an ending node
  def node_recurse(startnode, name_steps)
    if not startnode.nil? and not name_steps.empty?
      #puts "Starting at #{startnode["name"]} and going through #{name_steps}"
      next_dir = name_steps.shift
      #puts "Next step is #{next_dir}"
      next_node = startnode
      startnode["file"].each do |child|
        #puts "Comparing #{child['name']} to #{next_dir}"
        if child["name"] == next_dir
          #puts "Found the matching child"
          next_node = child
          break
        end
      end
      if next_node != startnode
        # Good. That means we found the next child.
        #puts "Found #{next_dir}. Recursing for #{name_steps}"
        return node_recurse(next_node, name_steps)
      else
        # Uh. Oh. The next child was not found in the startnode's file list. This must indicate a bad path
        puts "ERROR: At startnode #{startnode["name"]}, could not find the next child of #{next_dir}. Remaining paths: #{name_steps}"
        return startnode
      end
    else
      if startnode.nil?
        puts "Why? The startnode is Nil!"
      end
      return startnode
    end
  end

  def cd(rootnode, pwdnode, *cmdargs)
    if rootnode.nil?
      puts 'How the F is the rootnode nil? That should NOT happen'
    end

    if cmdargs.length > 0
      tgtdir = cmdargs.shift
      if /^\d+$/ =~ tgtdir
        puts "Tgtdir was an integer: #{tgtdir}"
        tgtdir = get_pwd_hash(pwdnode)[tgtdir.to_i]
        if tgtdir.nil?
          puts "Sorry, but that folder is outside the range."
          return nil
        end
        puts "Changed tgtdir to the real-name: #{tgtdir}"
      end

      if pwdnode["path"].nil?
        puts 'The current directory has no path! Ah!'
      end

      chdir = nil
      if tgtdir == '..'
        if not pwdnode["path"].nil?
          # We need the pwdnode's path not to be null, since we're going to use it to determine the previous directory
          pathSplit = pwdnode["path"].split('/')
          if pathSplit[0].empty?
            pathSplit.shift
          end
          # Skip the root-node's name
          pathSplit.shift
          #puts "Path split for .. was #{pathSplit}"
          if pathSplit.length >= 1
            chdir = node_recurse rootnode, (pathSplit.first pathSplit.length-1)
          else
            # If the pathSplit without the root-name has no length, then we're trying to do /.. (cd .. from root)
            # Do nothing.
          end
        end
      else
        filelist = pwdnode["file"]
        if not filelist.nil?
          filelist.each do |f|
            if f["name"] == tgtdir
              puts "CDing to #{tgtdir}"
              if f["path"].nil?
                # If the desired directory doesn't yet have a path, define it as the previous directory's path + the next directory's name
                f["path"] = pwdnode["path"] + '/' + f["name"]
              end
              return f
            end
          end
        end
      end

      if chdir.nil?
        puts "Invalid directory: #{tgtdir}"
        return nil
      else
        return chdir
      end
    end
  end

  # Return the path of the specified target directory
  def use(rootnode, pwdnode, targetdir)
    if pwdnode["path"].nil?
      puts "ERROR: The current directory has no path. We cannot find the targetdir's path"
    else
      if targetdir.nil?
        puts "Cannot use a NIL directory"
      else
        puts "Trying to use #{targetdir} from #{pwdnode['path']}"
        if targetdir =~ /^\d+$/
          puts "Tgtdir was an integer: #{targetdir}"
          targetdir = get_pwd_hash(pwdnode)[targetdir.to_i]
          if targetdir.nil?
            puts "Sorry, but that folder is outside the range."
            return nil
          end
          puts "Changed tgtdir to the real-name: #{targetdir}"
        end

        filelist = pwdnode["file"]
        if not filelist.nil?
          filelist.each do |f|
            if f["name"] == targetdir
              puts "Verified, and using #{targetdir}"
              if f["path"].nil?
                # If the desired directory doesn't yet have a path, define it as the previous directory's path + the next directory's name
                f["path"] = pwdnode["path"] + '/' + f["name"]
              end
              return f["path"]
            end
          end
        end
      end
    end
  end

  def browse_server_for_path
    raw_hash = get_repo_hash
    # Initialize PWD to root
    rootnode = raw_hash.parsed_response["repository"]
    rootnode["path"] = '/'
    rootnode["name"] = rootnode["path"][1, rootnode["path"].length]
    # We set the rootnode's path to /
    puts "Rootnode name is #{rootnode['name']} and path is #{rootnode['path']}"
    pwdnode = rootnode

    loop do
      if pwdnode.nil?
        puts 'WTF bro? the PWD is nil!'
      end
      print '%> '
      command = STDIN.gets.chomp
      if command.nil?
        puts "I'm sorry, but that's not a valid command!"
      elsif command == 'exit'
        break
      elsif command == 'ls'
        show_pwd(pwdnode)
        #puts get_pwd(pwdnode)
      else
        command_split = command.split(' ', 2)
        if command_split[0] == 'use'
          # The user is specifying the folder to deploy to. We want to stop the repl, and return that folder path
          deploy_path = use(rootnode, pwdnode, command_split[1])
          if deploy_path.nil?
            puts "Sorry, cannot use that directory"
          else
            puts "Deploy path was chosen: #{deploy_path}"
            # TODO Reduce any sequences of '/' to just 1. (Remove //'s)
            #return deploy_path
          end
        else
          maybe_newpwd = send(command_split.shift, rootnode, pwdnode, *command_split)
          if not maybe_newpwd.nil?
            pwdnode = maybe_newpwd
          end
        end
      end
    end
  end

  # Make a mapping from index to file/folder name, and return that map
  def get_pwd_hash(pwdnode)
    pwd_hash = {}
    pwdnode["file"].to_enum.with_index(1).each do |filefolder, index|
      pwd_hash[index] = filefolder["name"]
    end
    return pwd_hash
  end

  def show_pwd(pwdnode)
    puts "0 (pwd): #{pwdnode["name"]}"
    index = 1
    pwdnode["file"].each do |filefolder|
      if filefolder["isDirectory"] == 'true'
        puts "#{index}: #{filefolder["name"]}"
        index += 1
      end
    end
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

# Takes a mapping file 'local file name' => 'server file name'
# And asks the user for any edits they'd like to make: report title, output-type, server-file-name, etc.
def ask_edits(file_hash)
  ready = false
  while not ready
    puts "Index \tLocalName \tRemoteName \tTitle \tOutput \tLock?"
    file_table = [['Index', 'LocalName', 'RemoteName', 'Title', 'Output', 'Lock?']]

    # Generate a mapping from index to file_name when displaying the files
    index = 1
    # Create a 2D array to be used by Terminal-Table
    file_hash.each do |key, value|
      this_row = []
      this_row << index.to_s
      this_row << key.to_s
      this_row << value.to_s
      this_row << get_title(key)
      this_row << get_output_type(key)
      this_row << get_output_lock(key)
      file_table << this_row

      index += 1
    end

    # Type-check everything. EVERYTHING should be a string
    # Not exactly necesary
=begin
    errors = false
    file_table.each_index do |rindex|
      this_row = file_table[rindex]
      this_row.each_index do |cindex|
        this_col = this_row[cindex]
        if not this_col.is_a? String
          puts "The value at #{rindex},#{cindex} was NOT a string. It was a #{this_col.class}"
          errors = true
        end
      end
    end
    if errors
      puts 'AH! Type-errors arose!'
      exit(0)
    end
=end

    # Display the table
    puts 'Displaying the table!'
    puts Terminal::Table.new rows: file_table

    puts 'Which file would you like to edit?'
    filenum = STDIN.gets.chomp
    if filenum =~ /^\d+$/
      filenum = filenum.to_i
    else
      puts 'Please choose one of the file-indexes'
      next
    end

    # TODO Modify that file
    if filenum > file_table.length-1
      puts 'Index out of range.'
      next
    end

    if filenum == '0'
      break
    end
  end

  return file_hash
end

# Returns a list of length=2 (used like a tuple) containing the username and password
def get_username()
    print "Username for pentaho?"
    username = ''
    username = STDIN.gets.chomp
    return username
end

def get_password()
    print 'Password:'
    password = STDIN.noecho(&:gets).chomp
    puts ''
    return password
end

def handle_publish(commands)
  cmd = commands.shift

  if cmd == 'ls'
    server = commands.shift
    pconn = PentahoConnection.new(get_username(), get_password(), server)
    puts pconn.get_repo_hash
  elsif cmd == 'browse'
    server = commands.shift
    pconn = PentahoConnection.new(get_username(), get_password(), server)
    path = pconn.browse_server_for_path
    puts "Chosen path: #{path}"
  elsif cmd == 'file'
    username = get_username()
    password = get_password()
    serverlist = [server]

    # Capture all the next arguments that begin with 'http://'
    # Those will be servers to publish to
    loop do
      if commands[0].start_with?('http://')
        serverlist << commands.shift
      else
        break
      end
    end

    path = commands.shift
    if path[0] != '/'
      commands.unshift path
      path = nil
    end

    # and the file list is the remainder
    files = commands

    # Default server-names to the name of the file
    files_hash = {}
    files.each do |f|
      files_hash[f] = f
    end


    # ask for any final file-edits
    # Afterwards, the publishing commences
    files_hash = ask_edits(files_hash)

    # TODO: Create the file->binary hash

    # Check if this path starts with /  If not, we'll have to assume it's a report file or xaction, and resort to using the server browser

    # Iterate over all the servers, and publish to each
    serverlist.each do |server|
      pconn = PentahoConnection.new(username, password, server)

      if path.nil?
        path = pconn.browse_server_for_path
      end
      puts "Publishing to server: #{server}, path: #{path}, file-list: #{files}"


      #puts pconn.publish_report(files, path, pubpass)

    end




  else
    puts <<-helpdoc
Usage:
publish <COMMAND> <server> [OPTIONS]"

Possible commands:
    ls      Show the solution repository (XML)
    help    Show this usage doc
    file    publish a file
    browse  browse the server
OPTIONS
      publish file [server] [path] [files...]
      publish browse [server]
helpdoc

  end
end
