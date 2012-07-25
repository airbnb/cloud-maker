Gem::Specification.new do |s|
  s.name        = 'cloud-maker'
  s.version     = '0.0.0'
  s.date        = '2012-07-20'
  s.summary     = "Launch and perform initial configuration of cloud servers."
  s.authors     = ["Nathan Baxter", "Flo Leibert"]
  s.email       = 'nathan.baxter@airbnb.cloud-maker'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.homepage    = 'https://github.com/airbnb/cloud-maker'
  s.executables = ["cloud-maker"]
  s.add_runtime_dependency "colorize"
  s.add_runtime_dependency "thor", "~> 0.15"
  s.add_runtime_dependency "right_aws", '~> 3.0'

end
