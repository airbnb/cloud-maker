require 'right_aws'

module CloudMaker
  class Ec2
    # Public: Gets/Sets the AWS access key.
    attr_accessor :aws_secret_access_key
    # Public: Gets/Sets the AWS secret.
    attr_accessor :aws_access_key_id
    # Internal: Gets/Sets the RightAws::Ec2 instance.
    attr_accessor :ec2

    # Public: The name of the tag that will be used to find the name of an s3 bucket for archiving/information retrieval
    BUCKET_TAG = 's3_archive_bucket'

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
    def initialize(options)
      required_keys = [:aws_access_key_id, :aws_secret_access_key]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end

      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]

      self.ec2 = RightAws::Ec2.new(self.aws_access_key_id, self.aws_secret_access_key)
    end

    # Public: Fetch archived information about an instance
    #
    # Returns a hash of information about the instance as it was launched
    def info(instance_id)
      bucket = self.ec2.describe_tags(:filters => {'resource-id' => instance_id, 'key' => BUCKET_TAG}).first[:value]
      archiver = S3Archiver.new(
        :instance_id => instance_id,
        :aws_access_key_id => self.aws_access_key_id,
        :aws_secret_access_key => self.aws_secret_access_key,
        :bucket_name => bucket
      )
      archiver.load_archive
    end

    # Public: Terminates the specified EC2 instance.
    #
    # Returns a RightAws supplied Hash describing the terminated instance.
    def terminate(instance_id)
      self.ec2.terminate_instances([instance_id])
    end

    # Public: Launches a new EC2 instance, associates any specified elastic IPS
    # with it, adds any specified tags, and archives the launch details to S3.
    #
    # Returns a RightAws supplied Hash describing the launched instance.
    def launch(cloud_maker_config)
      user_data = cloud_maker_config.to_user_data

      instance = ec2.launch_instances(cloud_maker_config['ami'],
        :group_names => cloud_maker_config['security_group'],
        :instance_type => cloud_maker_config['instance_type'],
        :key_name => cloud_maker_config['key_pair'],
        :user_data => user_data
      ).first

      instance_id = instance[:aws_instance_id]

      ec2.create_tags(instance_id, cloud_maker_config["tags"]) if cloud_maker_config["tags"]

      if (cloud_maker_config["elastic_ip"])
        #we can't associate IPs while the state is pending
        while instance[:aws_state] == 'pending'
          #this is going to hammer EC2 a bit, it might be necessary to add some delay in here
          instance = ec2.describe_instances([instance_id]).first
        end

        ec2.associate_address(instance_id, :public_ip => cloud_maker_config["elastic_ip"])
      end

      instance = ec2.describe_instances([instance_id]).first # So we get updated tag/ip info

      archiver = S3Archiver.new(
        :instance_id => instance_id,
        :aws_access_key_id => self.aws_access_key_id,
        :aws_secret_access_key => self.aws_secret_access_key,
        :bucket_name => cloud_maker_config["tags"][BUCKET_TAG]
      )
      archiver.store_archive(cloud_maker_config, instance)

      instance
    end
  end
end
