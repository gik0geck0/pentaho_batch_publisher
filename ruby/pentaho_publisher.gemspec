Gem::Specification.new do |s|
  s.name        = 'pentaho_publisher'
  s.version     = '0.1.0'
  s.date        = '2013-10-01'
  s.summary     = 'Pentaho Publishing Utilities'
  s.description = 'Set of libraries to allow easy file-publication to a pentaho BI-server'
  s.authors     = ['Matt Buland']
  s.email       = 'gik0geck0@gmail.com'
  s.license     = 'MIT'
  s.files       = ['lib/pentaho_publisher/publisher_utils', 'lib/pentaho_publisher/prpt_utils']
  s.executables << 'pentaho-publish'
end
