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

  def to_user_data
    env_run_cmds = []
    self.options.each_pair do |key, properties|
      if properties[:environment] && !properties[:value].nil?
        escaped_value = properties[:value].to_s.gsub(/"/, '\\\\\\\\\"')
        env_run_cmds.push "echo \"#{key}=\\\"#{escaped_value}\\\"\" >> /etc/environment"
      end
    end

    user_data_config = self.cloud_config.dup
    user_data_config['runcmd'] ||= []
    user_data_config['runcmd'] = env_run_cmds.concat(user_data_config['runcmd'])
    return "#cloud-config\n#{user_data_config.to_yaml}"
  end


  def [](key)
    self.options[key][:value]
  end

  def []=(key, val)
    self.options[key][:value] = val
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
