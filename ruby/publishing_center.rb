#!/usr/bin/env ruby

#require_relative 'publish.rb'
#require 'pentaho_publisher/publishing_utils'
#require 'pentaho_publisher/prpt_utils'
require 'tk'

root = TkRoot.new

# This is a GUI client for the pentaho batch publisher
content = Tk::Tile::Frame.new(root) {padding "3 3 12 12"}
content.grid :column => 0, :row => 0, :sticky => 'nsew'

namelbl = Tk::Tile::Label.new(content) {text "Choose Files"}
files_frame = Tk::Tile::Frame.new(content) { borderwidth 5; relief "sunken"; }

#$option_one = TkVariable.new( 1 )
#one = Tk::Tile::CheckButton.new(content) {text "One"; variable $option_one; onvalue 1}
#$option_two = TkVariable.new( 0 )
#two = Tk::Tile::CheckButton.new(content) {text "Two"; variable $option_two; onvalue 1}
#$option_three = TkVariable.new( 1 )
#three = Tk::Tile::CheckButton.new(content) {text "Three"; variable $option_three; onvalue 1}

clear = Tk::Tile::Button.new(content) {text "Clear Files"}
serverlbl = Tk::Tile::Label.new(content) {text "Destination Server"}
pathlbl = Tk::Tile::Label.new(content) {text "Destination Path"}
destServer = Tk::Tile::Entry.new(content)
destPath = Tk::Tile::Entry.new(content)
browse = Tk::Tile::Button.new(content) {text "Browse"}
cancel = Tk::Tile::Button.new(content) {text "Cancel"}
publish = Tk::Tile::Button.new(content) {text "Publish"}


namelbl.grid :column => 0, :row => 0, :columnspan => 4, :sticky => 'nw', :padx => 5
files_frame.grid :column => 0, :row => 1, :columnspan => 4, :sticky => 'nsew'

clear.grid :column => 0, :row => 2, :sticky => 'new', :pady => 5, :padx => 5
serverlbl.grid :column => 0, :row => 3
destServer.grid :column => 1, :row => 3

pathlbl.grid :column => 0, :row => 4
destPath.grid :column => 1, :row => 4
browse.grid :column => 2, :row => 4

cancel.grid :column => 2, :row => 5
publish.grid :column => 3, :row => 5

TkGrid.columnconfigure( root, 0, :weight => 1 )
TkGrid.rowconfigure( root, 0, :weight => 1 )

TkGrid.columnconfigure( content, 1, :weight => 1 )
TkGrid.rowconfigure( content, 1, :weight => 1)

Tk.mainloop
