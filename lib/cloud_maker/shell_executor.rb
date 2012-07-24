module CloudMaker
    class ShellExecutor
    YAML_DOMAIN = "!airbnb.com,2012-07-19"
    YAML_TYPE = "shell-script"

    attr_accessor :script

    def initialize(script)
      self.script = script
    end

    def to_yaml_type
      "#{YAML_DOMAIN}/#{YAML_TYPE}"
    end

    def to_yaml(opts = {})
      YAML.quick_emit( nil, opts ) { |out|
        out.scalar( "tag:yaml.org,2002:str", execute, :plain )
      }
    end

    def execute
      @result ||= `#{self.script}`.chomp
    end

    def to_s
      execute
    end

    def self.from_string_representation(string_representation)
      ShellExecutor.new(string_representation)
    end
  end
end

YAML::add_domain_type(CloudMaker::ShellExecutor::YAML_DOMAIN, CloudMaker::ShellExecutor::YAML_TYPE) do |type, val|
  CloudMaker::ShellExecutor.from_string_representation(val)
end
