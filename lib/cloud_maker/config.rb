require 'yaml'
require 'stringio'

module CloudMaker
  class Config
    # Public: Gets/Sets the CloudMaker specific properties. The options hash
    # is formatted as:
    #    {
    #      'key1' => {
    #         'environment': boolean,
    #         'required': boolean,
    #         'value': value
    #      },
    #      'key2' => { ... },
    #      ...
    #    }
    attr_accessor :options
    # Public: Gets/Sets the Hash of Cloud Init properties. See
    # https://help.ubuntu.com/community/CloudInit for valid options
    attr_accessor :cloud_config
    # Public: Gets/Sets an Array of URLs to be included, this corresponds to the
    # list of URLs in a Cloud Init includes file.
    attr_accessor :includes
    # Public: Gets/Sets extra information about the config to be stored for
    # archival purposes.
    attr_accessor :extra_options

    # Internal: A mime header for the Cloud Init config section of the user data
    CLOUD_CONFIG_HEADER = %Q|Content-Type: text/cloud-config; charset="us-ascii"\nMIME-Version: 1.0\nContent-Transfer-Encoding: 7bit\nContent-Disposition: attachment; filename="cloud-config.yaml"\n\n|
    # Internal: A mime header for the includes section of the user data
    INCLUDES_HEADER = %Q|Content-Type: text/x-include-url; charset="us-ascii"\nMIME-Version: 1.0\nContent-Transfer-Encoding: 7bit\nContent-Disposition: attachment; filename="includes.txt"\n\n|
    # Internal: A multipart mime header for describing the entire user data
    # content. It includes a placeholder for the boundary text '___boundary___'
    # that needs to be replaced in the actual mime document.
    MULTIPART_HEADER = %Q|Content-Type: multipart/mixed; boundary="___boundary___"\nMIME-Version: 1.0\n\n|

    # Internal: If you don't specify a property associated with a key in the
    # cloud_maker config file we will use these properties to fill in the blanks
    DEFAULT_KEY_PROPERTIES = {
      "environment" => true,
      "required" => false,
      "value" => nil
    }

    # Public: Initializes a new CloudMaker object.
    #
    # cloud_config - A Hash describing all properties of the CloudMaker config.
    #   'cloud_maker' - The configuration properties for CloudMaker. These can
    #                   be specified either as
    #                      key: value
    #                   or as
    #                      key: {
    #                        environment: boolean,
    #                        required: boolean,
    #                        value: value
    #                      }
    #                   If specified as key: value DEFAULT_KEY_PROPERTIES will
    #                   be used. If the detailed version is used all properties
    #                   are optional and DEFAULT_KEY_PROPERTIES will be used to
    #                   fill in the blanks.
    #
    #   'include'     - An array of URLs or a String containing 1 URL per line
    #                   with optional # prefixed lines as comments.
    #   ...           - All valid properties of a Cloud Init config
    #                   are also valid here. See:
    #                   https://help.ubuntu.com/community/CloudInit
    # extra_options - Extra information about the instantiation. These will not
    #                 be used to launch the instance but will be stored in the
    #                 archive describing the instance.
    #
    # Returns a CloudMaker object
    def initialize(cloud_config, extra_options)
      self.extra_options = extra_options
      cloud_config = cloud_config.dup
      self.options = extract_cloudmaker_config!(cloud_config)
      self.includes = extract_includes!(cloud_config)
      self.cloud_config = cloud_config
    end

    # Public: Check if the CloudMaker config is in a valid state.
    #
    # Returns true if and only if all required properties have non-nil values
    #   and false otherwise.
    def valid?
      self.options.all? {|key, option| !(option["required"] && option["value"].nil?)}
    end

    # Public: Finds a list of keys in the CloudMaker config that are required to
    # have a value but do not yet have one.
    #
    # Returns an Array of required keys that are missing values.
    def missing_values
      self.options.select {|key, option| option["required"] && option["value"].nil?}.map(&:first).map(&:dup)
    end

    # Returns a Hash of all of the CloudMaker specific properties in the configuration.
    def to_hash
      self.options.map {|key, properties| [key, properties["value"]]}
    end

    # Public: Generate an archive of the cloudmaker configuration
    #
    # Returns an IO object containing the archive.
    def to_archive
      StringIO.new("my archive")
    end

    # Public: Generates a multipart userdata string suitable for use with Cloud Init on EC2
    #
    # Returns a String containing the mime encoded userdata
    def to_user_data
      # build a multipart document
      parts = []

      parts.push(CLOUD_CONFIG_HEADER + cloud_config_data)
      parts.push(INCLUDES_HEADER + includes_data)

      #not that it's likely but lets make sure that we don't choose a boundary that exists in the document.
      boundary = ''
      while parts.any? {|part| part.index(boundary)}
        boundary = "===============#{rand(8999999999999999999) + 1000000000000000000}=="
      end

      header = MULTIPART_HEADER.sub(/___boundary___/, boundary)

      return [header, *parts].join("\n--#{boundary}\n") + "\n--#{boundary}--"
    end

    # Public: Generates a cloud-init configuration
    #
    # Returns a String containing the cloud init configuration in YAML format
    def cloud_config_data
      env_run_cmds = []
      self.options.each_pair do |key, properties|
        if properties["environment"] && !properties["value"].nil?
          escaped_value = properties["value"].to_s.gsub(/"/, '\\\\\\\\\"')
          env_run_cmds.push "echo \"#{key}=\\\"#{escaped_value}\\\"\" >> /etc/environment"
        end
      end

      user_data_config = self.cloud_config.dup
      user_data_config['runcmd'] ||= []
      user_data_config['runcmd'] = env_run_cmds.concat(user_data_config['runcmd'])
      return "#cloud-config\n#{user_data_config.to_yaml}"
    end

    # Public: Generates a cloud-init includes list
    #
    # Returns a String containing the cloud init includes list
    def includes_data
      ["#include", *self.includes.map(&:to_s)].join("\n")
    end


    # Public: Access values in the cloudmaker options object
    #
    # key - The key of the property you're accessing
    #
    # Returns the value property for options[key]
    def [](key)
      self.options[key] ? self.options[key]["value"] : nil
    end

    # Public: Sets the value property for key in the cloudmaker options hash
    #
    # key - The key of the property you're accessing
    # val - The value you wish to assign to the key
    #
    # Returns val
    def []=(key, val)
      if (self.options[key])
        self.options[key]["value"] = val
      else
        self.options[key] = DEFAULT_KEY_PROPERTIES.merge('value' => val)
      end
      val
    end

    # Returns a String representation of the CloudMaker config
    def inspect
      "CloudMakerConfig#{self.options.inspect}"
    end

    class << self

      # Public: Takes the path of a YAML file and loads a new Config object
      # from it.
      #
      # instance_config_yaml - The path of the YAML file
      #
      # Returns a new Config
      # Raises: Exception if the file doesn't exist.
      # Raises: SyntaxError if the YAML file is invalid.
      def from_yaml(instance_config_yaml)
        begin
          full_path = File.expand_path(instance_config_yaml)
          cloud_yaml = File.open(full_path, "r") #Right_AWS will base64 encode this for us
        rescue
          raise "ERROR: The path to the CloudMaker config is incorrect"
        end

        CloudMaker::Config.new(YAML::load(cloud_yaml), :config_path => full_path)
      end
    end



    private

    # Internal: Takes a CloudMaker config and parses out the CloudMaker
    # specific portions of it. For each key/value it fills in any property
    # blanks from the DEFAULT_KEY_PROPERTIES. It also deletes the cloud_maker
    # property from config.
    #
    # config - A hash that should contain a 'cloud_maker' key storing CloudMaker
    #   configuration properties.
    #
    # Returns a Hash in the format of
    #   {'key1' => {
    #      'environment' => ...,
    #      'value' => ...,
    #      'required' ...
    #   }, 'key2' => ... , ...}
    def extract_cloudmaker_config!(config)
      cloud_maker_config = config.delete('cloud_maker') || {}
      cloud_maker_config.keys.each do |key|
        #if key is set to anything but a hash then we treat it as the value property
        if !advanced_config?(cloud_maker_config[key])
          cloud_maker_config[key] = {
            "value" => cloud_maker_config[key]
          }
        end

        cloud_maker_config[key] = DEFAULT_KEY_PROPERTIES.merge(cloud_maker_config[key])
      end
      cloud_maker_config
    end

    # Internal: Determines if value should be treated as a value or a property
    # configuration hash. A property configuration hash would specify at least
    # one of environment, value, or required.
    #
    # value - The value to evaluate
    #
    # Returns true if value is a property configuration, and false if it's just
    #   a value
    def advanced_config?(value)
      value.kind_of?(Hash) && !(DEFAULT_KEY_PROPERTIES.keys & value.keys).empty?
    end

    # Internal: Takes a CloudMaker config and parses out the includes list. If
    # the list is an array it treats each entry as a URL. If it is a string it
    # treats the string as the contents of a Cloud Init include file.
    #
    # config - A hash that should contain an 'include' key storing the include
    # information.
    #
    # Returns an Array of URLs
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
end
