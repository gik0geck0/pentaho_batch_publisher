Pentaho Batch Publisher
=======================

Ruby program that can interface with a pentaho bi-server, and can batch-publish reports to one or more servers

Building the Gem:
    * cd ruby
    * make
    * make install
    Now, you can use require 'pentaho_publisher/publish_utils' in your own ruby program
    or, use the packaged binary (pentaho-publisher), which will be deployed in your
    gem/bin directory

Usage (straight from source):
    The main executable is ruby/publish.rb
    Use it to access all the functionality.

    Command Usage:
    ./ruby/publish.rb <module> [module options...]

    Available Modules:
      publish
      prpt

    For information on modules, run:
      ./ruby/publish.rb <module> help

Required gems:
* zip
* httpary
* httmultiparty

Deprication of Python:
    For internal-work use, the python-development has been dropped in favor of Ruby (since we have an internal gem repository).
    The python files remain since they represent how the port would look/feel, but aren't close at all to the end-result.

Ideas:
    Keep record of who publishes what report where
