require 'right_aws'

module CloudMaker
  class S3Archiver
    attr_accessor :config, :aws_secret_access_key, :aws_access_key_id, :instance, :bucket

    KEY_PREFIX = "cloud-maker"

    def initialize(cloud_maker_config, instance, options)
      self.config = cloud_maker_config
      self.instance = instance
      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]
      s3 = RightAws::S3.new(self.aws_access_key_id, self.aws_secret_access_key)
      self.bucket = s3.bucket(self.bucket_name)
    end

    def store_archive
      archive = self.config.to_archive
      self.bucket.put(self.key, archive)
    end

    def key
      if self.instance_id
        [KEY_PREFIX, self.instance_id].join('/')
      else
        raise RuntimeError.new("Attempted to generate a key name without an instance id.")
      end
    end

    def instance_id
      self.instance[:aws_instance_id]
    end

    def bucket_name
      raise RuntimeError.new("Attempted to access S3 bucket name, which hasn't been defined.") unless self.config["s3_archive_bucket"]
      self.config["s3_archive_bucket"]
    end

    def load_archive
      self.bucket.get(self.key)
    end
  end
end
