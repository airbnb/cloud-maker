class CloudMakerConfig
  attr_accessor :options, :cloud_config, :includes

  CLOUD_CONFIG_HEADER = %Q|Content-Type: text/cloud-config; charset="us-ascii"\nMIME-Version: 1.0\nContent-Transfer-Encoding: 7bit\nContent-Disposition: attachment; filename="cloud-config.yaml"\n\n|
  INCLUDES_HEADER = %Q|Content-Type: text/x-include-url; charset="us-ascii"\nMIME-Version: 1.0\nContent-Transfer-Encoding: 7bit\nContent-Disposition: attachment; filename="includes.txt"\n\n|
  MULTIPART_HEADER = %Q|Content-Type: multipart/mixed; boundary="___boundary___"\nMIME-Version: 1.0\n\n|

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
    self.includes = extract_includes!(cloud_config)
    self.cloud_config = cloud_config
  end

  def to_user_data
    # build a multipart document
    parts = []

    parts.push(CLOUD_CONFIG_HEADER + cloud_config_data)
    parts.push(INCLUDES_HEADER + includes_data)

    boundary = ''
    while parts.any? {|part| part.index(boundary)}
      boundary = "===============#{rand(8999999999999999999) + 1000000000000000000}=="
    end

    header = MULTIPART_HEADER.sub(/___boundary___/, boundary)

    return [header, *parts].join("\n--#{boundary}\n") + "\n--#{boundary}--"
  end

  # generate the cloud-config portion of the user data
  def cloud_config_data
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

  # generate the includes portion of the user data
  def includes_data
    ["#include", *self.includes.map(&:to_s)].join("\n")
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


  private

  def extract_cloudmaker_config!(config)
    cloud_maker_config = config.delete('cloud_maker') || {}
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

  def extract_includes!(config)
    includes = config.delete('include')

    #if we didn't specify it just use a blank array
    if includes.nil?
      includes = []
    #if we passed something other than an array turn it into a string and split it up into urls
    elsif !includes.kind_of?(Array)
      includes = includes.to_s.split("\n")
      includes.reject! {|line| line.strip[0] == "#" || line.strip.empty?}
    end

    includes
  end
end
