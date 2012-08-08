Gem::Specification.new do |s|
  s.name        = 'cloud-maker'
  s.version     = '0.2.1.pre'
  s.date        = '2012-08-08'
  s.summary     = "Launch and perform initial configuration of cloud servers."
  s.authors     = ["Nathan Baxter", "Flo Leibert"]
  s.email       = 'nathan.baxter@airbnb.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.homepage    = 'https://github.com/airbnb/cloud-maker'
  s.executables = ["cloud-maker"]
  s.add_runtime_dependency "colorize"
  s.add_runtime_dependency "thor", "~> 0.15"
  s.add_runtime_dependency "right_aws", '~> 3.0'
  s.add_runtime_dependency "deep_merge", '~> 1.0'
  s.add_development_dependency "pry"
end
