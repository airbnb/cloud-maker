Gem::Specification.new do |s|
  s.name        = 'cloud-maker'
  s.version     = '0.7.0'
  s.summary     = "Extends Ubuntu CloudInit to launch and configure cloud servers."
  s.authors     = ["Nathan Baxter", "Flo Leibert"]
  s.email       = 'nathan.baxter@airbnb.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
  s.homepage    = 'https://github.com/airbnb/cloud-maker'
  s.executables = ["cloud-maker"]
  s.add_runtime_dependency "colorize"
  s.add_runtime_dependency "thor", "~> 0.15"
  s.add_runtime_dependency "aws-sdk", '~> 1.6'
  s.add_runtime_dependency "rest-client", '~> 1.6'
  s.add_runtime_dependency "deep_merge", '~> 1.0'
  s.add_runtime_dependency 'ruby-termios', '~> 0.9'
  s.add_development_dependency "pry"
end
