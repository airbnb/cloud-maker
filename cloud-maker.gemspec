require 'bundler'

Gem::Specification.new do |s|
  s.name        = 'cloud-maker'
  s.version     = '0.1.2'
  s.date        = '2012-08-01'
  s.summary     = "Launch and perform initial configuration of cloud servers."
  s.authors     = ["Nathan Baxter", "Flo Leibert"]
  s.email       = 'nathan.baxter@airbnb.cloud-maker'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.homepage    = 'https://github.com/airbnb/cloud-maker'
  s.executables = ["cloud-maker"]
  s.add_bundler_dependencies
end
