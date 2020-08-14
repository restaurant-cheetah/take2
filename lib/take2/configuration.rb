# frozen_string_literal: true

require 'take2/backoff'

module Take2
  class Configuration
    CONFIG_ATTRS = [:retries,
                    :retriable,
                    :retry_proc,
                    :retry_condition_proc,
                    :backoff_intervals].freeze

    attr_accessor(*CONFIG_ATTRS)

    def initialize(options = {})
      # Defaults
      @retries = 3
      @retriable = [
        Net::HTTPRetriableError,
        Errno::ECONNRESET,
        IOError,
      ].freeze
      @retry_proc = proc {}
      @retry_condition_proc = proc { false }
      @backoff_intervals = Backoff.new(:constant, 3).intervals

      merge_options!(options)
    end

    def to_hash
      CONFIG_ATTRS.each_with_object({}) do |key, hash|
        hash[key] = public_send(key)
      end
    end

    def [](value)
      public_send(value)
    end

    def merge_options!(options = {})
      validate!(options)
      options.each do |key, value|
        public_send("#{key}=", value)
      end
      self
    end

    def validate!(options)
      options.each do |k, v|
        raise ArgumentError, "#{k} is not a valid configuration" unless CONFIG_ATTRS.include?(k)
        case k
        when :retries
          raise ArgumentError, "#{k} must be positive integer" unless v.is_a?(Integer) && v.positive?
        when :retriable
          raise ArgumentError, "#{k} must be array of retriable errors" unless v.is_a?(Array)
        when :backoff_intervals
          raise ArgumentError, "#{k} must be array of retriable errors" unless v.is_a?(Array)
          raise ArgumentError, "#{k} size must be greater or equal to number of retries" unless v.size >= retries
        when :retry_proc, :retry_condition_proc
          raise ArgumentError, "#{k} must be Proc" unless v.is_a?(Proc)
        end
      end
    end
  end
end
