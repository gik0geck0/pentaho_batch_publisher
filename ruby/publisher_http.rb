#!/usr/bin/env ruby

#require 'shoes'

require_relative 'publisher_utils'

args = ARGV
mod = args.shift

if mod == 'publish'
  publisher_utils::handle(args)
end
