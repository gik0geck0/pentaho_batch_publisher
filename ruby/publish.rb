#!/usr/bin/env ruby

require_relative 'publisher_utils'
require_relative 'prpt_utils'

args = ARGV
mod = args.shift

# Lookup arguments. Unfortunately the long way. Because there's only 2 modules
if mod == 'publish'
  handle_publish(args)
elsif mod == 'prpt'
  handle_prpt(args)
else mod == 'help'
  puts <<-HELPDOC
Usage:
    #{$0} <module> [module options...]

Available Modules:
  publish
  prpt

For information on modules, run:
  #{$0} <module> help

HELPDOC
end
