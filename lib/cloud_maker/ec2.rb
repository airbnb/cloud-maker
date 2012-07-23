require 'yaml'
require 'right_aws'

module CloudMaker
  class Ec2
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

      instance = ec2.launch_instances(config['ami'],
        :group_names => config['security_group'],
        :instance_type => config['instance_type'],
        :key_name => config['key_pair'],
        :user_data => user_data
      )

      instance_id = instance[:aws_instance_id]

      ec2.associate_address(instance_id, self.config["elastic_ip"]) if (self.config["elastic_ip"])
      ec2.create_tags(instance_id, self.config["tags"]) if self.config["tags"]

      instance
    end

    def valid?
      !self.config.nil? &&
      !self.aws_secret_access_key.nil? && !self.aws_secret_access_key.empty? &&
      !self.aws_access_key_id.nil? && !self.aws_access_key_id.empty?
    end
  end
end
