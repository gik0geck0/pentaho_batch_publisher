#!/usr/bin/env ruby

#require_relative 'publish.rb'
require 'pentaho_publisher/publisher_utils'
#require 'pentaho_publisher/prpt_utils'
require 'tk'

# This is a GUI client for the pentaho batch publisher

def create_main_window()

  # Root is the main window. If this is closed/destroyed, ALL children will also close.
  root = TkRoot.new

  # Content is a single frame inside the root.
  content = Tk::Tile::Frame.new(root) {padding "3 3 12 12"}
  content.grid :column => 0, :row => 0, :sticky => 'nsew'

  namelbl = Tk::Tile::Label.new(content) {text "Choose Files"}
  files_frame = Tk::Tile::Frame.new(content) { borderwidth 5; relief "sunken";}

  addFile = Tk::Tile::Button.new(content) {text "Add Files"}
  clearFiles = Tk::Tile::Button.new(content) {text "Clear Files"}
  serverlbl = Tk::Tile::Label.new(content) {text "Destination Server"}
  pathlbl = Tk::Tile::Label.new(content) {text "Destination Path"}
  $servertext = TkVariable.new
  destServer = Tk::Tile::Entry.new(content) { textvariable $servertext; }
  destPath = Tk::Tile::Entry.new(content)
  browse = Tk::Tile::Button.new(content) {text "Browse"}
  cancel = Tk::Tile::Button.new(content) {text "Cancel"}
  publish = Tk::Tile::Button.new(content) {text "Publish"}

  # Place the widgets in a grid-layout
  namelbl.grid :column => 0, :row => 0, :columnspan => 4, :sticky => 'nw', :padx => 5
  files_frame.grid :column => 0, :row => 1, :columnspan => 4, :sticky => 'nsew'

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
  browse.bind("1") { create_server_browser(root, getServerlist($servertext)) }
  cancel.bind("1") { exit(0) }
  addFile.bind("1") do
    fname = Tk::getOpenFile(:multiple => true, :parent => content)
    puts "Adding these files: #{fname}"
  end

  Tk.mainloop
end

def getServerlist(serverText)
  #puts "Looking at the servers: #{serverText}"
  return serverText.to_s.split
  #return []
end

def create_server_browser(parent, serverlist)

  # Have the user login first
  pconn = get_login(parent, serverlist)
  puts "Get-login returned with #{pconn}"
  if pconn.nil?
    # There must not be a server entered. Don't create this window.
    return
  end

  browser_window = TkToplevel.new(parent)
  browser_window['geometry'] = '400x400+100+100'
  #browser_window.minsize(:height => 200, :width => 200)

  content = Tk::Tile::Frame.new(browser_window) { padding "3 3 12 12"; pack :side => 'top', 'fill' => "both", 'expand' => 'yes'; }
  #testlbl = Tk::Tile::Label.new(browser_window) { text "HEY LOOK AT ME, IM TAKING UP SPACE" }

  namelbl = Tk::Tile::Label.new(content) { text "Browsing the server for files!"; pack :side => 'top', :fill => 'x' }
  files_frame = Tk::Tile::Frame.new(content) { borderwidth 5; relief "sunken"; pack :side => 'top', 'fill' => "both", 'expand' => 'yes'; }

  control_frame = Tk::Tile::Frame.new(content) { padding "3 3 12 12"; pack :side => 'top', :fill => 'x'}
  pathlbl = Tk::Tile::Label.new(control_frame) { text "Path:"; pack :side => 'left'}
  pathname = Tk::Tile::Entry.new(control_frame) { text "/"; pack :side => 'left'}
  cancel = Tk::Tile::Button.new(control_frame) {text "Cancel"; pack :side => 'left'}
  choose = Tk::Tile::Button.new(control_frame) {text "Choose"; pack :side => 'left'}

  #content.grid :column => 0, :row => 0, :padx => 5
  #testlbl.grid :column => 0, :row => 1

  #namelbl.grid :column => 0, :row => 0, :padx => 5
  #files_frame.grid :column => 0, :row => 1, :padx => 5
  #control_frame.grid :column => 0, :row => 2

  #pathlbl.grid :column => 0, :row => 0
  #pathname.grid :column => 1, :row => 0
  #cancel.grid :column => 2, :row => 0
  #choose.grid :column => 3, :row => 0

  # Make the window scalable. This allows the content-frame to scale.
  #TkGrid.columnconfigure( browser_window, 0, :weight => 1, :minsize => 200 )
  #TkGrid.rowconfigure( browser_window, 0, :weight => 1, :minsize => 200 )

  #TkGrid.columnconfigure(content, 0, :weight => 1, :minsize => 200)
  #TkGrid.rowconfigure(content, 0, :weight => 1, :minsize => 200)
end

def get_login(parent, serverlist)
  if serverlist.empty?
    msg = Tk.messageBox({ :message => 'Please entry at least one server first.', :title => 'Server Required', :type => "ok", :icon => "error" })
    return nil
  end
  browser_window = TkToplevel.new(parent)
  #browser_window['geometry'] = '400x400+100+100'
  #browser_window.minsize(:height => 200, :width => 200)

  content = Tk::Tile::Frame.new(browser_window) { padding "3 3 12 12"; pack :side => 'top', 'fill' => "both", 'expand' => 'yes'; }
  #testlbl = Tk::Tile::Label.new(browser_window) { text "HEY LOOK AT ME, IM TAKING UP SPACE" }

  $unvar = TkVariable.new
  namelbl = Tk::Tile::Label.new(content) { text "Username:"; pack :anchor => 'nw' }
  nameentry = Tk::Tile::Entry.new(content) { textvariable $unvar; pack :anchor => 'n' }

  $pwvar = TkVariable.new
  pwlbl = Tk::Tile::Label.new(content) { text "Password"; pack :anchor => 'sw' }
  pwentry = Tk::Tile::Entry.new(content) { show '**********'; textvariable $pwvar; pack :anchor => 's' }

  login = Tk::Tile::Button.new(content) { text "Login"; pack :anchor => 'se' }
  cancel = Tk::Tile::Button.new(content) { text "Cancel"; pack :anchor => 'se' }

  login.bind("1") { browser_window.destroy }
  cancel.bind("1") { $unvar = ''; $pwvar = ''; browser_window.destroy }

  # Let's pause here, so the user can put in their login info, and after, we can return it
  browser_window.wait_window

  # Allow no-passwords (though I don't know if pentaho does)
  if $unvar == ''
    return nil
  end

  # Create a new connection to the first server in the list
  return PentahoConnection.new $unvar.to_s, $pwvar.to_s, serverlist[0]
end

puts "Tk.instance_methods: #{Tk.instance_methods}"
puts "Tk.constants: #{Tk.constants}"

create_main_window()

=begin Variable example

$option_one = TkVariable.new( 1 )
one = Tk::Tile::CheckButton.new(content) {text "One"; variable $option_one; onvalue 1}
$option_two = TkVariable.new( 0 )
two = Tk::Tile::CheckButton.new(content) {text "Two"; variable $option_two; onvalue 1}
$option_three = TkVariable.new( 1 )
three = Tk::Tile::CheckButton.new(content) {text "Three"; variable $option_three; onvalue 1}

=end
