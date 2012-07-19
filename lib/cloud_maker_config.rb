class CloudMakerConfig
  attr_accessor :options, :cloud_config

  # If you don't specify a property associated with a key in the cloud_maker config file
  # we will use these properties to fill in the blanks
  DEFAULT_KEY_PROPERTIES = {
    :environment => true,
    :required => false,
    :value => nil
  }

  def initialize(cloud_config)
    cloud_config = cloud_config.dup
    self.options = extract_cloudmaker_config!(cloud_config)
    self.cloud_config = cloud_config
  end

  def [](key)
    self.options[key]
  end

  def []=(key, val)
    self.options[key] = val
  end

  def inspect
    "CloudMakerConfig#{self.options.inspect}"
  end

  def extract_cloudmaker_config!(config)
    cloud_maker_config = config.delete('cloud_maker')
    cloud_maker_config.keys.each do |key|
      #if key is set to anything but a hash then we treat it as the value property
      if !cloud_maker_config[key].kind_of?(Hash)
        cloud_maker_config[key] = {
          :value => cloud_maker_config[key]
        }
      end

      cloud_maker_config[key] = DEFAULT_KEY_PROPERTIES.merge(cloud_maker_config[key])
    end
    cloud_maker_config
  end
end
