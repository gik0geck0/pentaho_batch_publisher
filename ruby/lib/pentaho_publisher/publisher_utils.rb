#!/usr/bin/env ruby

# Set of functions that can be used to interface with a pentaho server

require 'rubygems'
require 'httparty'
require 'httmultiparty'
require 'digest/md5'
require 'io/console'
require 'pp'
require 'terminal-table'
require_relative 'prpt_utils'


class PentahoConnection

  def initialize(username, password, server='')
    @auth = { username: username, password: password }
    @server = server
  end

  public # public methods allow interfacing with the pentaho server with specific actions

  # Gets the hash representation of a pentaho server's solution repository
  def get_repo_hash
    begin
    hash = get '/SolutionRepositoryService?component=getSolutionRepositoryDoc'
    rescue Errno::ECONNREFUSED
      puts 'Connection refused. Bad username/password combo?'
      exit(-1)
    end
  end

  def get_pub_pass
    print 'Publishing Password:'
    pubpass = get_stdin(:noecho)
    if pubpass.nil?
      cancel_publish
    else
      pubpass.chomp!
      return pubpass
    end
  end

  # Publish a list of prpts to the pentaho server
  def publish_report(files, path, pubpass=get_pub_pass(), overwrite=true, mkdirs=false)

    # files used to be a list of only local filepaths. files is now a hash from remotename => binarydata
    # What used to be params (a hash of MultiPart components) is now files

    # Moved to just outside the publish function
    # params = {}
    # files should be a list of file names
    #files.each do |f|
    #  puts "Filename: #{CGI::escape(f)}"

      #openfile = File.new f, 'rb'
      #params[URI.encode(f)] = openfile#.read #.encode(Encoding::UTF_8)
      #v = URI.escape(params[URI.encode(f)], Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      #openfile.close
    #end
    path = CGI::escape(path)
    action_url = "/RepositoryFilePublisher?publishPath=#{path}&publishKey=#{get_passkey(pubpass)}&overwrite=#{overwrite}&mkdirs=#{mkdirs}"

    puts "Action url:", action_url
    return post action_url, files
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
      dirnum = cmdargs.shift
      if /^\d+$/ =~ dirnum
        #puts "Tgtdir was an integer: #{dirnum}"
        pwd_hash = get_pwd_hash(pwdnode, true)
        #puts "Full PwdHash is #{pwd_hash}"
        tgtdir = pwd_hash[dirnum.to_i]
        if tgtdir.nil?
          puts "Index out of range. Expected < #{pwd_hash.length}, but got #{dirnum.to_i}"
          return nil
        end
        puts "Changed tgtdir to the real-name: #{tgtdir}"
      else
        tgtdir = dirnum
      end

      if pwdnode["path"].nil?
        puts 'The current directory has no path! Ah!'
      end

      chdir = nil
      if tgtdir == '..'
        #puts "CDing ..  #{pwdnode['path'].nil?}"
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
            #puts "Chdir is now #{chdir}"
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
              #puts "CDing to #{tgtdir}"
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
        #puts "Trying to use #{targetdir} from #{pwdnode['path']}"
        if targetdir =~ /^\d+$/
          #puts "Tgtdir was an integer: #{targetdir}"
          if targetdir.to_i > 0
            targetdir = get_pwd_hash(pwdnode, true)[targetdir.to_i]
            if targetdir.nil?
              puts "Sorry, but that folder is outside the range."
              return nil
            end
          else
            # Choosing 0 means choose this directory
            # I guess if a negative number is chosen, then we'll just assume use .
            return pwdnode["path"]
          end
          puts "Changed tgtdir to the real-name: #{targetdir}"
        elsif targetdir == '.'
          # use . == use PWD
          return pwdnode["path"]
        end


        filelist = pwdnode["file"]
        if not filelist.nil?
          filelist.each do |f|
            if f["name"] == targetdir
              #puts "Verified, and using #{targetdir}"
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
    #puts "Rootnode name is #{rootnode['name']} and path is #{rootnode['path']}"
    pwdnode = rootnode

    helpdoc = <<-HELPDOC
    Available commands:
      help    show this list of commands
      ls      list contents of the current directory
      cd      change current directory to another (specified by either index or Name. Previous directory is '..'
      use     choose a directory (specified by either index, or Name)
      exit    quit, and decide not to choose a directory
    HELPDOC
    puts helpdoc


    loop do
      if pwdnode.nil?
        puts 'WTF bro? the PWD is nil!'
      end
      print '%> '
      command = get_stdin()
      if command.nil?
        puts "I'm sorry, but that's not a valid command!"
      elsif command == 'exit'
        break
      elsif command == 'ls'
        show_pwd(pwdnode)
        #puts get_pwd(pwdnode)
      elsif command =='help'
        puts helpdoc
      else
        command_split = command.split(' ', 2)
        if command_split[0] == 'use'
          # The user is specifying the folder to deploy to. We want to stop the repl, and return that folder path
          deploy_path = use(rootnode, pwdnode, command_split[1])
          if deploy_path.nil?
            puts "Sorry, cannot use that directory"
          else
            # Reduce any sequences of '/' to just 1. (Remove //'s)
            deploy_path = deploy_path.sub /\/\/+/, '/'
            puts "Deploy path was chosen: #{deploy_path}"
            return deploy_path
          end
        elsif command_split[0] == 'ls'
          # Remove the ls, so we can use its args
          com = command_split.shift
          show_pwd(pwdnode, *command_split)
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
  def get_pwd_hash(pwdnode, dir_only=false)
    pwd_hash = {}
    index = 1
    pwdnode["file"].each do |filefolder|
      if !dir_only or filefolder["isDirectory"] == 'true'
        pwd_hash[index] = filefolder["name"]
        index += 1
      end
    end
    return pwd_hash
  end

  def show_pwd(pwdnode, *args)
    show_all = false
    if args.include?('-a')
      show_all = true
    end
    puts "0 (pwd): #{pwdnode["name"]}"
    index = 1
    pwdnode["file"].each do |filefolder|
      if filefolder["isDirectory"] == 'true'
        puts "#{index}: #{filefolder["name"]}"
        index += 1
      elsif show_all
        puts " : #{filefolder["name"]}"
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
    puts "Query params are: #{query}"
    return HTTMultiParty.post(server+action, query: query, basic_auth: auth, base_uri: server)
  end

end

########## Helper Functions ##########

def cancel_publish
    puts 'Cancelling publish'
    exit(-1)
end

# STDIN.gets.chomp with nil-protection (like if C-d is pressed)
# This is used mostly to decrease the number of errors generated
def get_stdin(*args)
    if args.include?(:noecho)
      val = STDIN.noecho(&:gets)
    else
      val = STDIN.gets
    end

    if val.nil?
      cancel_publish
    else
      val.chomp!
      return val
    end
end

def get_username()
    print "Username for pentaho?"
    username = ''
    username = get_stdin()
    return username
end

def get_password(prompt='Password:')
    print prompt
    password = get_stdin(:noecho)
    puts ''
    return password
end

def print_help()
    puts <<-helpdoc
Usage:
publish <COMMAND> <server> [OPTIONS]"

Possible commands:
    ls      Show the solution repository (XML)
    help    Show this usage doc
    file    publish a file
    browse  browse the server interactively

OPTIONS
      publish file <servers...> [path] <files...>
          if the path is not specified, an interactive server-browser will be used
      publish browse <server>
helpdoc
end

# Takes a mapping file 'local file name' => 'server file name'
# And asks the user for any edits they'd like to make: report title, output-type, server-file-name, etc.
def ask_edits(file_hash)
  ready = false
  while not ready
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
    puts Terminal::Table.new rows: file_table

    puts 'Which file would you like to edit?'
    puts 'Select it by the index. Choosing an index of 0 will indicate that you are done editing.'
    filenum = get_stdin()
    if filenum =~ /^\d+$/
      filenum = filenum.to_i
    else
      puts 'Please choose one of the file-indexes'
      next
    end

    if filenum > file_table.length
      puts "Index out of range. Expected < #{file_table.length}, but got #{filenum}"
      next
    elsif filenum == 0
      # choosing 0 means no edits are desired
      break
    else
      loop do
        # Alright. Let's modify it!
        puts "You chose the file #{file_table[filenum][1]}"
        puts 'What would you like to change?'
        puts '0: Cancel'
        puts "1: Destination : #{file_table[filenum][2]}"
        puts "2: Title       : #{file_table[filenum][3]}"
        puts "3: Output-Type : #{file_table[filenum][4]}"
        puts "4: Output-Lock : #{file_table[filenum][5]}"
        puts "5: Remove File"
        edit_choice = get_stdin()
        if edit_choice =~ /^\d+$/
          edit_choice = edit_choice.to_i
          if edit_choice == 0
            break
          elsif edit_choice == 5
            puts "Removing #{file_table[filenum][1]}!"
            file_table.pop!(filenum)
          else
            puts 'New value?'
            nval = get_stdin()
            if edit_choice == 1
              # Change the file hash's value, using the key from the file_table, so that next outer-loop will refresh the table, and capture the new value
              file_hash[file_table[filenum][1]] = nval
              break
            else
              # Do a call into the prpt utils to change the report
              # file_table[filenum][1] == The report's local name/location
              if edit_choice == 2
                puts "Setting title to #{nval}"
                set_title(file_table[filenum][1], nval)
              elsif edit_choice == 3
                puts "Setting output to #{nval}"
                set_output_type(file_table[filenum][1], nval)
              elsif edit_choice == 4
                puts "Setting output lock to #{nval}"
                set_output_lock(file_table[filenum][1], nval)
              else
                put "I don't actually know how you got here...??"
              end

              # Finish editings. Refresh file-list
              break
            end
          end
        else
          puts "That's not a valid choice. Please try again"
          next
        end
      end
    end
  end

  return file_hash
end

def handle_publish(commands)
  cmd = commands.shift

  if cmd == 'ls'
    server = commands.shift
    pconn = PentahoConnection.new(get_username(), get_password(), server)
    puts pconn.get_repo_hash
  elsif cmd == 'browse'
    if commands.length < 1
      print_help()
      exit(-1)
    end
    server = commands.shift
    pconn = PentahoConnection.new(get_username(), get_password(), server)
    path = pconn.browse_server_for_path
    puts "Chosen path: #{path}"
  elsif cmd == 'file'
    if commands.length < 2
      print_help()
      exit(-1)
    end

    serverlist = []

    # Capture all the next arguments that begin with 'http://'
    # Those will be servers to publish to
    #puts "Server list is #{serverlist}"
    loop do
      if commands[0].start_with?('http://')
        if not commands[0].end_with?(':8080/pentaho')
          puts "Warning: the server #{commands[0]} does not access port 8080 with the base-action of pentaho. You should be sure this is what's wanted."
        end
        serverlist << commands.shift
      else
        break
      end
    end
    #puts "Server list is #{serverlist}"
    if serverlist.empty?
      puts "Servers must start with 'http://'. Please check the arguments passed in. At least one server is needed."
      exit(-1)
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
      if FileTest.exist? f
        files_hash[f] = f
      else
        puts "Warning: #{f} does not exist"
      end
    end

    # Check that we have some files that exist to publish
    if files_hash.empty?
      puts "At least one existing file is needed when publishing. Otherwise, what's supposed to be published?"
      exit(-1)
    end


    # ask for any final file-edits
    # Afterwards, the publishing commences
    files_hash = ask_edits(files_hash)

    # Create the file->binary hash
    binary_hash = {}
    files_hash.each do |localfname, remotefname|
      openfile = File.new localfname, 'rb'
      binary_hash[URI.encode(remotefname)] = openfile
    end

    # Check if this path starts with /  If not, we'll have to assume it's a report file or xaction, and resort to using the server browser

    # Fetch username and password just before the connection is needed
    username = get_username()
    password = get_password()
    # Iterate over all the servers, and publish to each
    serverlist.each do |server|
      pconn = PentahoConnection.new(username, password, server)

      if path.nil?
        puts "Getting path from the server #{server}"
        path = pconn.browse_server_for_path
      end
      puts "Publishing to server: #{server}, path: #{path}, file-list: #{files}"


      pubpass = get_password("Publishing Password:")
      # Chomp the end. There's likely newlines
      publish_response = pconn.publish_report(binary_hash, path, pubpass).chomp
      puts 'Finished the publish command'

=begin
  FILE_EXISTS = 1;
  FILE_ADD_FAILED = 2;
  FILE_ADD_SUCCESSFUL = 3;
  FILE_ADD_INVALID_PUBLISH_PASSWORD = 4;
  FILE_ADD_INVALID_USER_CREDENTIALS = 5;
=end
      response_meanings = {
        '1' => "Error: File exists. Did you mean to turn replacement on?",
        '2' => "Error: File Add Failed. (Though I don't have any information on why)",
        '3' => "Report Published Sucessfully!",
        '4' => "Error: Invalid Publishing Password.",
        '5' => "Error: Invalid user credentials."
      }
      puts "Response was: #{publish_response}. What is lookup 2? #{response_meanings['2']}"
      meaningful_response = response_meanings[publish_response]
      if not meaningful_response.nil?
        puts meaningful_response
      else
        puts "Publish failed for some unknown reason. Would you like to see the response from the BI-server? (y/n)"
        want_to_see = get_stdin().downcase

        if want_to_see == 'y'
          puts publish_response
        end
      end

    end




  else
    print_help

  end
end
