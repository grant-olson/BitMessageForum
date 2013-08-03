Gem::Specification.new do |s|
  s.name        = 'bmf'
  s.version     = '0.2.0'
  s.date        = '2013-08-02'
  s.summary     = "BitMessageForum!"
  s.description = "Browse bitmessages in a forum-like environment."
  s.authors     = ["Grant T. Olson"]
  s.email       = 'kgo@grant-olson.net'
  s.files       = ["lib/bmf.rb"]
  s.files	+= Dir.glob("lib/bmf/lib/*.rb")
  s.files	+= Dir.glob("lib/bmf/views/*.haml")
  s.files	+= Dir.glob("lib/bmf/public/**/*")
  s.files	+= Dir.glob("config/settings.yml.sample")

  s.executables << "bmf"

  s.homepage    =
    'https://github.com/grant-olson/BitMessageForum'
  s.license       = 'BSD'

  s.add_dependency "thin", "~> 1.5.1"
  s.add_dependency "sinatra", "~> 1.4.3"
  s.add_dependency "sinatra-contrib", "~> 1.4.0"
  s.add_dependency "haml", "~> 4.0.3"
  s.add_dependency "sanitize"

end