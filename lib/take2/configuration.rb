module Take2
  class Configuration
    CONFIG_ATTRS = [:retries, :retriable, :retry_proc, :retry_condition_proc, :time_to_sleep].freeze
    attr_accessor(*CONFIG_ATTRS)

    def initialize(options = {})
      # Defaults
      @retries = 3
      @retriable = [
        Net::HTTPServerError,
        Net::HTTPServerException,
        Net::HTTPRetriableError,        
        Errno::ECONNRESET,
        IOError,
       ].freeze
      @retry_proc = proc { |error, tries| log_client_error error, tries }
      @retry_condition_proc = proc { false }
      @time_to_sleep = 3
      # Overwriting the defaults
      options.each do |k, v|
        raise ArgumentError, "#{k} is not a valid configuration"  unless CONFIG_ATTRS.include?(k)
        raise ArgumentError, "#{k} must be positive integer"      unless v.is_a?(Integer) && v.positive?
        raise ArgumentError, "#{k} must be positive number"       unless (v.is_a?(Integer) || v.is_a?(Float)) && v.positive?
        instance_variable_set(:"@#{k}", v)
      end
    end

    def to_hash
      CONFIG_ATTRS.each_with_object({}) do |key, hash|
        hash[key] = public_send(key)
      end
    end

    def [](value)
      self.public_send(value)
    end

    private

    def log_client_error(error, tries)
      Rails.logger.warn "#{self.name} - Retrying.. #{tries} of #{self.retries} (#{error})"
    end

  end
end