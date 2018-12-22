module Take2
  class Configuration
    CONFIG_ATTRS = [:retries, :retriable, :retry_proc, :retry_condition_proc, :time_to_sleep].freeze
    attr_accessor(*CONFIG_ATTRS)

    def initialize(options = {})
      # Defaults
      @retries = 3
      @retriable = [
        Net::HTTPServerException,
        Net::HTTPRetriableError,        
        Errno::ECONNRESET,
        IOError,
       ].freeze
      @retry_proc = proc {}
      @retry_condition_proc = proc { false }
      @time_to_sleep = 3
      # Overwriting the defaults
      validate_options(options, &setter)
    end

    def to_hash
      CONFIG_ATTRS.each_with_object({}) do |key, hash|
        hash[key] = public_send(key)
      end
    end

    def [](value)
      self.public_send(value)
    end

    def validate_options(options, &setter)
      options.each do |k, v|
        raise ArgumentError, "#{k} is not a valid configuration"  unless CONFIG_ATTRS.include?(k)
        case k
          when :retries
            raise ArgumentError, "#{k} must be positive integer" unless v.is_a?(Integer) && v.positive?
          when :time_to_sleep  
            raise ArgumentError, "#{k} must be positive number" unless (v.is_a?(Integer) || v.is_a?(Float)) && v >= 0
          when :retriable
            raise ArgumentError, "#{k} must be array of retriable errors" unless v.is_a?(Array)
          when :retry_proc, :retry_condition_proc
            raise ArgumentError, "#{k} must be Proc" unless v.is_a?(Proc)
        end
        setter.call(k, v) if block_given?
      end  
    end

    def setter
      proc { |key, value| instance_variable_set(:"@#{key}", value) }
    end

  end
end