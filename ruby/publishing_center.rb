#!/usr/bin/env ruby

#require_relative 'publish.rb'
#require 'pentaho_publisher/publishing_utils'
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
  destServer = Tk::Tile::Entry.new(content)
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
  TkGrid.columnconfigure( root, 0, :weight => 1 )
  TkGrid.rowconfigure( root, 0, :weight => 1 )
  # Make a scaling unit in the center. This makes everything finite-size EXCEPT the things in col1 or ro1, which are expandable.
  TkGrid.columnconfigure( content, 1, :weight => 1 )
  TkGrid.rowconfigure( content, 1, :weight => 1)

  # Event Binding
  browse.bind("1") { create_server_browser root }
  cancel.bind("1") { exit(0) }
  addFile.bind("1") do
    fname = Tk::getOpenFile
    puts "Adding this file: #{fname}"
  end

  Tk.mainloop
end

def create_server_browser(parent)
  browser_window = TkToplevel.new(parent)
  browser_window['geometry'] = '400x400+100+100'
  content = Tk::Tile::Frame.new(browser_window) { padding "3 3 12 12" }
  namelbl = Tk::Tile::Label.new(content) { text "Browsing the server for files!" }

  content.grid :column => 0, :row => 0, :sticky => 'nw', :padx => 5
  namelbl.grid :column => 0, :row => 0, :sticky => 'nw', :padx => 5

  # Make the window scalable. This allows the content-frame to scale.
  TkGrid.columnconfigure( browser_window, 0, :weight => 1 )
  TkGrid.rowconfigure( browser_window, 0, :weight => 1 )
end

create_main_window()

=begin Variable example

$option_one = TkVariable.new( 1 )
one = Tk::Tile::CheckButton.new(content) {text "One"; variable $option_one; onvalue 1}
$option_two = TkVariable.new( 0 )
two = Tk::Tile::CheckButton.new(content) {text "Two"; variable $option_two; onvalue 1}
$option_three = TkVariable.new( 1 )
three = Tk::Tile::CheckButton.new(content) {text "Three"; variable $option_three; onvalue 1}

=end
