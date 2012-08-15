module CloudMaker
  class S3Archiver

    # Public: Gets/Sets the AWS access key.
    attr_accessor :aws_secret_access_key
    # Public: Gets/Sets the AWS secret.
    attr_accessor :aws_access_key_id
    # Public: Gets/Sets the EC2 instance ID string.
    attr_accessor :instance_id
    # Internal: Gets/Sets the bucket object used for storing/loading archives.
    attr_accessor :bucket

    # Public: All archive keys will be prefixed with KEY_PREFIX/
    KEY_PREFIX = "cloud-maker"

    INSTANCE_YAML = 'instance.yaml'
    CLOUD_CONFIG_YAML = 'cloud_config.yaml'


    # Public: Creates a new S3 Archiver instance
    #
    # options - S3 configuration options
    #           :aws_access_key_id     - (required) The AWS access key
    #           :aws_secret_access_key - (required) The AWS secret
    #           :bucket_name           - (required) The bucket for the archiver to access
    #           :instance_id           - (required) The AWS instance ID the archive describes
    #
    # Returns a new CloudMaker::S3Archiver instance
    # Raises RuntimeError if any of the required options are not specified
    def initialize(options)
      required_keys = [:aws_access_key_id, :aws_secret_access_key, :instance_id, :bucket_name]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end

      self.instance_id = options[:instance_id]
      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]

      self.bucket = AWS::S3.new(
        :access_key_id => self.aws_access_key_id,
        :secret_access_key => self.aws_secret_access_key
      ).buckets[options[:bucket_name]]

      raise RuntimeError.new("The S3 bucket #{options[:bucket_name]} does not exist.") unless self.bucket.exists?
    end

    # Public: Generates an archive with all information relevant to an instance
    # launch and stores it to S3.
    #
    # cloud_maker_config - The CloudMaker::Config the instance was launched with
    # properties         - A Hash describing the properties of the launched instance
    #
    # Returns nothing.
    def store_archive(cloud_maker_config, properties)
      userdata = cloud_maker_config.to_user_data
      self.bucket.objects.create(self.user_data_key, :data => userdata)
      self.bucket.objects.create(self.instance_yaml_key, :data => properties.to_yaml)
      self.bucket.objects.create(self.cloud_config_yaml_key, :data => cloud_maker_config.to_hash.to_yaml)
      true
    end

    # Public: Retrieves a previously created archive from S3
    #
    # Returns the content of the archive.
    def load_archive
      {
        :user_data => self.bucket.objects[self.user_data_key].read,
        :cloud_config => YAML::load(self.bucket.objects[self.cloud_config_yaml_key].read),
        :instance => YAML::load(self.bucket.objects[self.instance_yaml_key].read)
      }
    end

    # Internal: Returns the key for the user_data file
    def user_data_key
      self.prefix_key('user_data')
    end

    # Internal: Returns the key for the instance yaml file
    def instance_yaml_key
      self.prefix_key('instance.yaml')
    end

    # Internal: Returns the key for the cloud config yaml file
    def cloud_config_yaml_key
      self.prefix_key('cloud_config.yaml')
    end


    # Public: Returns the key that the archive will be stored under
    def prefix_key(key)
      if self.instance_id
        [KEY_PREFIX, self.instance_id, key].join('/')
      else
        raise RuntimeError.new("Attempted to generate a key name without an instance id.")
      end
    end
  end
end
