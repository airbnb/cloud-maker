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
          'default' => '',
          'description' => "An elastic IP address you control that you would like to associate to the instance."
        },
        'security_group' => {
          'default' => 'default',
          'required' => true,
          'description' => 'The Amazon EC2 security group to launch the instance with.'
        },
        'iam_role' => {
          'default' => '',
          'description' => 'The IAM instance profile name or ARN you would like to use.'
        },
        'cname' => {
          'default' => '',
          'description' => "A dns entry you would like to CNAME to this instance."
        },
        'block_device_mappings' => {
          'description' => "A hash of block devices mappings. ie. { /dev/sda1 => { volume_size => <value_in_GB>, snapshot_id => <id>, delete_on_termination => <boolean> } }"
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
      instance = find_instance(instance_id)
      bucket = instance.tags[BUCKET_TAG]

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
      find_instance(instance_id).terminate
    end

    # Public: Launches a new EC2 instance, associates any specified elastic IPS
    # with it, adds any specified tags, and archives the launch details to S3.
    #
    # Returns an AWS::EC2 object for the launched instance.
    def launch(cloud_maker_config)
      user_data = cloud_maker_config.to_user_data

      if !cloud_maker_config['availability_zone'].nil? && !cloud_maker_config['availability_zone'].empty?
        region = find_region(cloud_maker_config['availability_zone'])
      else
        region = ec2 # .instances.create will just put things in the default region
      end

      config = {
        :image_id => cloud_maker_config['ami'],
        :iam_instance_profile => cloud_maker_config['iam_role'],
        :security_groups => cloud_maker_config['security_group'],
        :instance_type => cloud_maker_config['instance_type'],
        :key_name => cloud_maker_config['key_pair'],
        :availability_zone => cloud_maker_config['availability_zone'],
        :user_data => user_data
      }
      config[:block_device_mappings] = cloud_maker_config['block_device_mappings'] if cloud_maker_config['block_device_mappings']

      instance = region.instances.create(config)

      begin
        instance.tags.set(cloud_maker_config['tags']) if cloud_maker_config['tags']
      rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
        retries ||= 0
        if retries < 5
          sleep(2**retries)
          retries += 1
          retry
        end
      end

      if cloud_maker_config.elastic_ip? || cloud_maker_config.cname?
        while instance.status == :pending
          #wait
        end
        instance.associate_elastic_ip(cloud_maker_config["elastic_ip"]) if cloud_maker_config.elastic_ip?

        if cloud_maker_config.cname?
          r53 = AWS::Route53::Client.new(:access_key_id => self.aws_access_key_id, :secret_access_key => self.aws_secret_access_key)

          zone = r53.list_hosted_zones[:hosted_zones].select {|zone|
            cloud_maker_config['cname'] + '.' =~ /#{Regexp.escape(zone[:name])}$/
          }.first

          r53.change_resource_record_sets(
            :hosted_zone_id => zone[:id],
            :change_batch => {
              :comment => "CloudMaker initialization of #{instance.instance_id}.", :changes => [{
                :action => "CREATE", :resource_record_set => {
                  :name => cloud_maker_config['cname'],
                  :type => 'CNAME',
                  :ttl => 60,
                  :resource_records => [{:value => instance.dns_name}]
                }
              }]
            }
          )
        end
      end

      archiver = S3Archiver.new(
        :instance_id => instance.id,
        :aws_access_key_id => self.aws_access_key_id,
        :aws_secret_access_key => self.aws_secret_access_key,
        :bucket_name => cloud_maker_config["tags"][BUCKET_TAG]
      )
      archiver.store_archive(cloud_maker_config, self.class.instance_to_hash(instance))

      instance
    end

    # Internal: Find the instance object for an instance ID regardless of what
    # region the instance is in. It looks in the default region (us-east-1) first
    # and then looks in all regions if it's not there.
    #
    # Returns nil or an AWS::EC2::Instance
    def find_instance(instance_id)
      # Check the default region first
      return ec2.instances[instance_id] if ec2.instances[instance_id].exists?

      # If we don't find it there look in every region
      instance = nil
      ec2.regions.each do |region|
        if region.instances[instance_id].exists?
          instance = region.instances[instance_id]
          break
        end
      end

      instance
    end


    # Internal: Find the region object for a given availability zone. Currently works
    # based on amazon naming conventions and will break if they change.
    #
    # Returns an AWS::EC2::Region
    # Raises a RuntimeError if the region doesn't exist
    def find_region(availability_zone)
      region_name = availability_zone.gsub(/(\d)\w$/, '\1')
      if ec2.regions[region_name].exists?
        ec2.regions[region_name]
      else
        raise RuntimeError.new("The region #{region_name} doesn't exist - region name generated from availability_zone: #{availability_zone}.")
      end
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
          :status => instance.status,
          :tags => instance.tags.inject({}) {|hash, tag| hash[tag.first] = tag.last;hash}
        }
      end
    end

  end
end
