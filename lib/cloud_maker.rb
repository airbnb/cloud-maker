require './lib/cloud_maker_config'
require 'right_aws'

class CloudMaker
  attr_accessor :config
  def initialize(cloud_maker_config)
    self.config = cloud_maker_config
  end

  def launch
    ec2 = RightAws::Ec2.new(self.config['AWS_ACCESS_KEY_ID'], self.config['AWS_SECRET_ACCESS_KEY'])
    binding.pry
  end

  class << self
    def from_yaml(instance_config_yaml)
      begin
        full_path = File.expand_path(instance_config_yaml)
        cloud_yaml = File.open(full_path, "r") #Right_AWS will base64 encode this for us
      rescue
        raise "ERROR: The path to the CloudMaker config is incorrect"
      end

      begin
        cloud_config = YAML::load(cloud_yaml)
      rescue
        raise "ERROR: The CloudMaker config contained invalid YAML syntax"
      end

      self.new(CloudMakerConfig.new(cloud_config))
    end
  end
end
