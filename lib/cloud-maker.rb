Bundler.require(ENV['CLOUDMAKER_ENV'].to_sym) if ENV['CLOUDMAKER_ENV']

require 'thor'
require 'colorize'
require 'deep_merge'
require 'right_aws'

require 'cloud_maker/config'
require 'cloud_maker/ec2'
require 'cloud_maker/s3_archiver'
require 'cloud_maker/shell_executor'

