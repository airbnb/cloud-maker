require 'right_aws'

module CloudMaker
  class EC2
    # Public: Gets/Sets the AWS access key.
    attr_accessor :aws_secret_access_key
    # Public: Gets/Sets the AWS secret.
    attr_accessor :aws_access_key_id
    # Internal: Gets/Sets the AWS::EC2 instance.
    attr_accessor :ec2

    # Public: A CloudMaker::Config hash that describes the config properties EC2 relies on.
    CLOUD_MAKER_CONFIG = {
      'cloud-maker' => {
        'ami' => {
          'required' => true,
          'description' => "The Amazon AMI ID for the instance."
        },
        'instance_type' => {
          'required' => true,
          'description' => "The Amazon instance type, eg. m1.small."
        },
        'availability_zone' => {
          'required' => true,
          'description' => "The Amazon availability zone, eg. us-east-1a"
        },
        'key_pair' => {
          'default' => "",
          'description' => "The name of an Amazon key pair, so you can actually login to the instance."
        },
        'elastic_ip' => {
          'description' => "An elastic IP address you control that you would like to associate to the instance."
        },
        'security_group' => {
          'default' => 'default',
          'required' => true,
          'description' => 'The Amazon EC2 security group to launch the instance with.'
        }
      }
    }

    # Public: The name of the tag that will be used to find the name of an s3 bucket for archiving/information retrieval
    BUCKET_TAG = 's3_archive_bucket'

    # Public: Creates a new EC2 instance
    #
    # cloud_maker_config - A CloudMaker::Config object describing the instance
    #                      to be managed.
    # options            - S3 configuration options
    #                      :aws_access_key_id     - (required) The AWS access key
    #                      :aws_secret_access_key - (required) The AWS secret
    #
    # Returns a new CloudMaker::EC2 instance
    # Raises RuntimeError if any of the required options are not specified
    def initialize(options)
      required_keys = [:aws_access_key_id, :aws_secret_access_key]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end

      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]

      self.ec2 = AWS::EC2.new(:access_key_id => self.aws_access_key_id, :secret_access_key => self.aws_secret_access_key)
    end

    # Public: Fetch archived information about an instance
    #
    # Returns a hash of information about the instance as it was launched
    def info(instance_id)
      bucket = ec2.instances[instance_id].tags[BUCKET_TAG]

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
    # Returns nothing.
    def terminate(instance_id)
      ec2.instances[instance_id].terminate
    end

    # Public: Launches a new EC2 instance, associates any specified elastic IPS
    # with it, adds any specified tags, and archives the launch details to S3.
    #
    # Returns an AWS::EC2 object for the launched instance.
    def launch(cloud_maker_config)
      user_data = cloud_maker_config.to_user_data

      instance = ec2.instances.create(
        :image_id => cloud_maker_config['ami'],
        :security_groups => cloud_maker_config['security_group'],
        :instance_type => cloud_maker_config['instance_type'],
        :key_name => cloud_maker_config['key_pair'],
        :availability_zone => cloud_maker_config['availability_zone'],
        :user_data => user_data
      )

      instance.tags.set(cloud_maker_config["tags"]) if cloud_maker_config["tags"]
      instance.associate_elastic_ip(cloud_maker_config["elastic_ip"]) if cloud_maker_config["elastic_ip"]

      archiver = S3Archiver.new(
        :instance_id => instance.id,
        :aws_access_key_id => self.aws_access_key_id,
        :aws_secret_access_key => self.aws_secret_access_key,
        :bucket_name => cloud_maker_config["tags"][BUCKET_TAG]
      )
      archiver.store_archive(cloud_maker_config, self.class.instance_to_hash(instance))

      instance
    end


    class << self
      # Public: Generates a hash of properties from an AWS::EC2 instance
      #
      # Returns a hash of properties for the instance.
      def instance_to_hash(instance)
        {
          :instance_id => instance.id,
          :ami => instance.image_id,
          :api_termination_disabled => instance.api_termination_disabled?,
          :dns_name => instance.dns_name,
          :ip_address => instance.ip_address,
          :private_ip_address => instance.private_ip_address,
          :key_name => instance.key_name,
          :owner_id => instance.owner_id,
          :status => instance.status
        }
      end
    end

  end
end
