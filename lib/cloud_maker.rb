require './lib/cloud_maker_config'
require 'right_aws'

class CloudMaker
  attr_accessor :config, :aws_secret_access_key, :aws_access_key_id

  def initialize(cloud_maker_config, options)
    self.config = cloud_maker_config
    self.aws_access_key_id = options[:aws_access_key_id]
    self.aws_secret_access_key = options[:aws_secret_access_key]
  end

  def launch
    ec2 = RightAws::Ec2.new(self.aws_access_key_id, self.aws_secret_access_key)

    user_data = self.config.to_user_data

    output = File.open('generated-cloud-config.yaml', 'w')
    output.puts user_data

    response = ec2.launch_instances(config['ami'],
      :group_names => config['security_group'],
      :instance_type => config['instance_type'],
      :key_name => config['key_pair'],
      :user_data => user_data
    )

    puts response.inspect
    binding.pry

  end

  def valid?
    !self.config.nil? &&
    !self.aws_secret_access_key.nil? && !self.aws_secret_access_key.empty? &&
    !self.aws_access_key_id.nil? && !self.aws_access_key_id.empty?
  end

  class << self
    def from_yaml(instance_config_yaml, options)
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

      self.new(CloudMakerConfig.new(cloud_config), options)
    end
  end
end
