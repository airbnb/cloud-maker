require 'right_aws'

module CloudMaker
  class Ec2
    # Public: Gets/Sets the AWS access key.
    attr_accessor :aws_secret_access_key
    # Public: Gets/Sets the AWS secret.
    attr_accessor :aws_access_key_id
    # Public: Gets/Sets the CloudMaker::Config
    attr_accessor :config

    # Public: Creates a new Ec2 instance
    #
    # cloud_maker_config - A CloudMaker::Config object describing the instance
    #                      to be managed.
    # options            - S3 configuration options
    #                      :aws_access_key_id     - (required) The AWS access key
    #                      :aws_secret_access_key - (required) The AWS secret
    #
    # Returns a new CloudMaker::Ec2 instance
    # Raises RuntimeError if any of the required options are not specified
    def initialize(cloud_maker_config, options)
      required_keys = [:aws_access_key_id, :aws_secret_access_key]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end

      self.config = cloud_maker_config
      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]
    end

    # Public: Launches a new EC2 instance, associates any specified elastic IPS
    # with it, adds any specified tags, and archives the launch details to S3.
    #
    # Returns a RightAws supplied Hash describing the launched instance.
    def launch
      ec2 = RightAws::Ec2.new(self.aws_access_key_id, self.aws_secret_access_key)

      user_data = self.config.to_user_data

      instance = ec2.launch_instances(config['ami'],
        :group_names => config['security_group'],
        :instance_type => config['instance_type'],
        :key_name => config['key_pair'],
        :user_data => user_data
      ).first

      instance_id = instance[:aws_instance_id]

      puts "Launched instance: #{instance_id.to_s.on_light_blue}"

      ec2.create_tags(instance_id, self.config["tags"]) if self.config["tags"]

      if (self.config["elastic_ip"])
        #we can't associate IPs while the state is pending
        while instance[:aws_state] == 'pending'
          print '.'
          STDOUT.flush
          #this is going to hammer EC2 a bit, it might be necessary to add some delay in here
          instance = ec2.describe_instances([instance_id]).first
        end

        ec2.associate_address(instance_id, :public_ip => self.config["elastic_ip"])

        instance = ec2.describe_instances([instance_id]).first # So we get the correct IP address
      end


      archiver = S3Archiver.new(
        :instance_id => instance_id,
        :aws_access_key_id => self.aws_access_key_id,
        :aws_secret_access_key => self.aws_secret_access_key,
        :bucket_name => self.config["s3_archive_bucket"]
      )
      archiver.store_archive(self.config, instance)

      instance
    end
  end
end
