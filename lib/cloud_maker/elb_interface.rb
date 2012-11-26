module CloudMaker
  class ElbInterface
    # Public: Gets/Sets the AWS access key.
    attr_accessor :aws_secret_access_key
    # Public: Gets/Sets the AWS secret.
    attr_accessor :aws_access_key_id
    # Public: Gets/Sets the EC2 instance.
    attr_accessor :instance
    # Internal: Gets/Sets the the elb name.
    attr_accessor :elb_name
    
    # Public: Creates a new ElbInterface instance
    #
    # options - Elb configuration options
    #           :aws_access_key_id     - (required) The AWS access key
    #           :aws_secret_access_key - (required) The AWS secret
    #           :elb_name              - (required) The name of the elb to use
    #           :instance           - (required) The AWS instance
    #
    # Returns a new CloudMaker::ElbInterface instance
    # Raises RuntimeError if any of the required options are not specified
    
    def initialize(options)
      required_keys = [:aws_access_key_id, :aws_secret_access_key, :instance, :elb_name]
      unless (required_keys - options.keys).empty?
        raise RuntimeError.new("Instantiated #{self.class} without required attributes: #{required_keys - options.keys}.")
      end
      
      self.instance = options[:instance]
      self.aws_access_key_id = options[:aws_access_key_id]
      self.aws_secret_access_key = options[:aws_secret_access_key]
      
      @elb = AWS::ELB.new(
        :access_key_id => self.aws_access_key_id,
        :secret_access_key => self.aws_secret_access_key
      ).load_balancers[options[:elb_name]]
    end
    
    def attach
      @elb.instances.register([self.instance])
      raise RuntimeError.new("The instance was not registerd correctly. id:#{self.instance.id}") unless @elb.instances[self.instance.id]
    end
  end
end
