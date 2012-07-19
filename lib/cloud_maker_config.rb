class CloudMakerConfig
  attr_accessor :options, :cloud_config

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
    config.delete('cloud_maker')
  end
end
