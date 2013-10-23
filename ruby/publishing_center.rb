#!/usr/bin/env ruby

#require_relative 'publish.rb'
require 'pentaho_publisher/publisher_utils'
require 'pentaho_publisher/prpt_utils'
require 'tk'
# Included package from http://www.nemethi.de/
# In ArchLinux, it's a community package for Tcl8.6 (symlinked for use in 8.5)
# On windows, it'll be necesary to copy the contents of the zip into a specific
# tcl-lib folder somewhere. I don't know where though.
require 'tkextlib/tcllib/tablelist'


# This is a GUI client for the pentaho batch publisher

def create_main_window()

  # Root is the main window. If this is closed/destroyed, ALL children will also close.
  root = TkRoot.new

  # Content is a single frame inside the root.
  content = Tk::Tile::Frame.new(root) {padding "3 3 12 12"}
  content.grid :column => 0, :row => 0, :sticky => 'nsew'
  content.raise

  $fileslist = []
  namelbl = Tk::Tile::Label.new(content) {text "Choose Files"}
  files_table = Tk::Tcllib::Tablelist.new(content) { 
    cols = columnzip(["Index", "Path", "Destination", "Title", "Output Type", "Lock"])
    #puts "Columns: #{cols}"
    columns cols.to_s
    #columns "0 'A' 1 'B' 2 'C' 3 'D' 4 'E' 5 'F' 6 'G'";
    stretch 'all'
    background 'white'
    foreground 'black'
    columnconfigure 0, :width => 5
    columnconfigure 1, :width => 20
    columnconfigure 2, :width => 20
    columnconfigure 3, :width => 10
    columnconfigure 4, :width => 5
    columnconfigure 5, :width => 5
    autoscroll
  }
  #files_table.expand '1'

  addFile = Tk::Tile::Button.new(content) {text "Add Files"}
  clearFiles = Tk::Tile::Button.new(content) {text "Clear Files"}
  serverlbl = Tk::Tile::Label.new(content) {text "Destination Server"}
  pathlbl = Tk::Tile::Label.new(content) {text "Destination Path"}

  $servertext = TkVariable.new
  destServer = Tk::Tile::Entry.new(content) { textvariable $servertext; }
  $pathtext = TkVariable.new
  destPath = Tk::Tile::Entry.new(content) { textvariable $pathtext; }

  browse = Tk::Tile::Button.new(content) {text "Browse"}
  cancel = Tk::Tile::Button.new(content) {text "Cancel"}
  publish = Tk::Tile::Button.new(content) {text "Publish"}

  # Place the widgets in a grid-layout
  namelbl.grid :column => 0, :row => 0, :columnspan => 4, :sticky => 'nw', :padx => 5
  files_table.grid :column => 0, :row => 1, :columnspan => 4, :sticky => 'nsew'

  addFile.grid :column => 2, :row => 0, :sticky => 'new', :pady => 5, :padx => 5
  clearFiles.grid :column => 3, :row => 0, :sticky => 'new', :pady => 5, :padx => 5
  serverlbl.grid :column => 0, :row => 3
  destServer.grid :column => 1, :row => 3

  pathlbl.grid :column => 0, :row => 4
  destPath.grid :column => 1, :row => 4
  browse.grid :column => 2, :row => 4

  cancel.grid :column => 2, :row => 5
  publish.grid :column => 3, :row => 5

  # Make the root scalable. This allows the content-frame to scale.
  TkGrid.columnconfigure( root, 0, :weight => 1 , :minsize => 400)
  TkGrid.rowconfigure( root, 0, :weight => 1, :minsize => 400)
  # Make a scaling unit in the center. This makes everything finite-size EXCEPT the things in col1 or row1, which are expandable.
  TkGrid.columnconfigure( content, 1, :weight => 1, :minsize => 400 )
  TkGrid.rowconfigure( content, 1, :weight => 1, :minsize => 400)

  # Event Binding
  browse.bind("1") do
    serverList = getServerlist($servertext);
    if not serverList.nil?
      # Open up a browser to get a path
      pname = create_server_browser(root, serverList[0])
      # Save it to the pathtext variable when it returns
      $pathtext.value= pname
    end
  end
  cancel.bind("1") { exit(0) }
  addFile.bind("1") do
    fname = Tk::getOpenFile(:multiple => true, :parent => content)
    if fname.include? "{"
      addfiles = multi_file_split fname
    else
      addfiles = fname.split
    end
    $fileslist.concat addfiles
    addfiles_totable(addfiles, files_table)
  end

  Tk.mainloop
end

# ftable is expected to be Tablelist (from tkextlib/tcllib/tablelist)
def addfiles_totable(flist, ftable)

  # Map from path to destination
  fdest = {}

  puts "Iterating through the files"
  flist.each_index do |idx|
    e = flist[idx]
    puts "Looking at index=#{idx}, and path=#{e}"

    fdest[e] = File.basename(e)
    puts "Set dest to #{fdest[e]}"

    thisrow = []
    thisrow << idx.to_s
    thisrow << e
    thisrow << fdest[e]

    # Use prpt-get functions if it's a prpt
    if e.end_with? ".prpt"
      title = get_title(e)
      outputtype = get_output_type(e)
      outputlock = get_output_lock(e)
    else
      title = "None"
      outputtype = "None"
      outputlock = "None"
    end
    puts "Set title to #{title}"
    puts "Set type to #{outputtype}"
    puts "Set lock to #{outputlock}"

    thisrow << title
    thisrow << outputtype
    thisrow << outputlock

    # Escape spaces
    thisrow.each do |col|
      col.gsub!(' ', '\\ ')
    end

    ftable.insert 0, thisrow
  end

  ftable.bind("1") { |event| gi = event.widget.grid_info(); puts "Clicked on row: #{gi['row']}, column: #{gi['column']}"; }
end

def maxsize(str, size)
  if str.length > size - 3
    "...".concat str[-size..-1]
  else
    str
  end
end

# files is a string that has a space-separated list of files. Caveat: literal spaces will appear like '\ '
def multi_file_split(files)
  flist = []
  puts "Splitting the string: #{files}"
  flist = files.split(/\} \{/)

  # The first string will start with '{', and the last string will end with '}'
  flist[0] = flist[0][1..-1]
  flist[-1] = flist[-1][0..-2]
  puts "Initial split: #{flist}"
  return flist
end

# Converts the input on the server-text into a list of servers. Will create an error-box if there are any problems, and if there's a critical error, nil will be returned
def getServerlist(serverText)
  slist = serverText.to_s.split
  if slist.empty?
    #msg = Tk.messageBox({ :message => 'Please entry at least one server first.', :title => 'Server Required', :type => "ok", :icon => "error" })
  end
  return slist
end

# Creates a GUI-browser for a remote server to pick a path
def create_server_browser(parent, server)

  # Have the user login first
  if server.nil?
    pconn = nil
  else
    pconn = get_login(parent, server)
  end

  puts "Get-login returned with #{pconn}"
  if pconn.nil?
    # There must not be a server entered. Don't create this window.
    return
  end

  browser_window = TkToplevel.new(parent)
  browser_window.raise
  browser_window['geometry'] = '400x400+100+100'
  #browser_window.minsize(:height => 200, :width => 200)

  content = Tk::Tile::Frame.new(browser_window) { padding "3 3 12 12"; pack :side => 'top', 'fill' => "both", 'expand' => 'yes'; }
  #testlbl = Tk::Tile::Label.new(browser_window) { text "HEY LOOK AT ME, IM TAKING UP SPACE" }

  namelbl = Tk::Tile::Label.new(content) { text "Browsing the server for files!"; pack :side => 'top', :fill => 'x' }
  files_frame = Tk::Tile::Frame.new(content) { borderwidth 5; relief "sunken"; pack :side => 'top', 'fill' => "both", 'expand' => 'yes'; }

  control_frame = Tk::Tile::Frame.new(content) { padding "3 3 12 12"; pack :side => 'top', :fill => 'x'}
  pathlbl = Tk::Tile::Label.new(control_frame) { text "Path:"; pack :side => 'left'}

  # starting path is '/'
  $pathname = TkVariable.new '/'
  pathname = Tk::Tile::Entry.new(control_frame) { textvariable $pathname; pack :side => 'left'; }
  cancel = Tk::Tile::Button.new(control_frame) {text "Cancel"; pack :side => 'left'}
  cancel.bind("1") { browser_window.destroy }
  choose = Tk::Tile::Button.new(control_frame) {text "Choose"; pack :side => 'left'}

  pathManager = PentahoConnection::PathPosition.new(pconn.get_repo_hash)

  pathsetter = lambda do |path|
    puts "Changing the path from #{$pathname.to_s} to #{path}"
    $pathname.value= sanitize_path path
  end

  refreshfunc = lambda do
    populate_repo_frame(files_frame, pathManager, pathsetter, refreshfunc)
  end
  # If the user presses enter after editing the path, refresh the window
  #pathname.bind("Return") { puts "Pathname hit enter!"; refreshfunc.call }

  refreshfunc.call

  # Wait for the path to be chosen, then return it
  browser_window.wait_window
  return $pathname.to_s
end

# Fill the frame with the contents of the pwdnode in the pathPosition
# Returns a hash from index -> name for the contents
# Also takes a function that's a closure to set the path in the window
def populate_repo_frame(frame, pathPos, setpathfunc, refreshfunc, dironly=true)
  #puts "Available frame instance methods:"
  #frame.class.instance_methods.each { |i| puts "#{i}:\t#{frame.method(i).arity}" }

  #puts "Current Frame children:"
  #frame.winfo_children.each { |c| puts c }

  # Remove all children from the frame (clear the frame)
  frame.winfo_children.each { |c| c.destroy }

  pwdhash = pathPos.get_pwd_hash(dironly)
  pwdhash[0] = '..'
  pwdhash.each do |idx, e|
    fileLabel = Tk::Tile::Label.new(frame) { text "#{idx}: #{e}"; pack :side => 'top', :fill => 'x', :expand => 'yes' }
    # Set the on-click listener
    fileLabel.bind("Double-1") { puts "The item #{idx}: #{e} was double-clicked!"; pathPos.cd e; setpathfunc.call(pathPos.get_pwd_path()); refreshfunc.call() }
    if idx != 0
      fileLabel.bind("1") { setpathfunc.call(pathPos.get_pwd_path() + '/' + e); puts "Path clicked was #{pathPos.get_pwd_path() + '/' + e}" }
    end
  end

  return pwdhash
end

def get_login(parent, server)
  browser_window = TkToplevel.new(parent)
  #browser_window['geometry'] = '400x400+100+100'
  #browser_window.minsize(:height => 200, :width => 200)

  content = Tk::Tile::Frame.new(browser_window) { padding "3 3 12 12"; pack :side => 'top', 'fill' => "both", 'expand' => 'yes'; }
  #testlbl = Tk::Tile::Label.new(browser_window) { text "HEY LOOK AT ME, IM TAKING UP SPACE" }

  $unvar = TkVariable.new
  namelbl = Tk::Tile::Label.new(content) { text "Username:"; pack :anchor => 'nw' }
  nameentry = Tk::Tile::Entry.new(content) { textvariable $unvar; pack :anchor => 'n' }
  nameentry.focus

  $pwvar = TkVariable.new
  pwlbl = Tk::Tile::Label.new(content) { text "Password"; pack :anchor => 'sw' }
  pwentry = Tk::Tile::Entry.new(content) { show '**********'; textvariable $pwvar; pack :anchor => 's' }

  login = Tk::Tile::Button.new(content) { text "Login"; pack :anchor => 'se' }
  cancel = Tk::Tile::Button.new(content) { text "Cancel"; pack :anchor => 'se' }

  login.bind("1") { browser_window.destroy }
  cancel.bind("1") { $unvar = ''; $pwvar = ''; browser_window.destroy }
  browser_window.bind("Return") { browser_window.destroy } # Do the SAME thing as login-button press

  # Let's pause here, so the user can put in their login info, and after, we can return it
  browser_window.wait_window

  # Allow no-passwords (though I don't know if pentaho does)
  if $unvar == ''
    return nil
  end

  # Create a new connection to the first server in the list
  return PentahoConnection.new $unvar.to_s, $pwvar.to_s, server
end

# Takes a list of columns, and produces an expected column format for tcl/Tablelist
# Ex. columnzip(["A", "B", "C"]) -> "0 'A' 1 'B' 2 'C'"
def columnzip(colnames)
  runningstr = ""
  colnames.each_index do |idx|
    runningstr += " #{idx} #{colnames[idx].gsub(' ', '\\ ')}"
  end
  return runningstr
end

#puts "Tk.instance_methods: #{Tk.instance_methods}"
#puts "Tk.constants: #{Tk.constants}"

create_main_window()

=begin Variable example

$option_one = TkVariable.new( 1 )
one = Tk::Tile::CheckButton.new(content) {text "One"; variable $option_one; onvalue 1}
$option_two = TkVariable.new( 0 )
two = Tk::Tile::CheckButton.new(content) {text "Two"; variable $option_two; onvalue 1}
$option_three = TkVariable.new( 1 )
three = Tk::Tile::CheckButton.new(content) {text "Three"; variable $option_three; onvalue 1}

=end
