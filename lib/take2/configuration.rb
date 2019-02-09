# frozen_string_literal: true

require 'take2/backoff'

module Take2
  class Configuration
    CONFIG_ATTRS = [:retries,
                    :retriable,
                    :retry_proc,
                    :retry_condition_proc,
                    :time_to_sleep,
                    :backoff_setup,
                    :backoff_intervals].freeze

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
      @start = @time_to_sleep # TODO: Soft deprecate time to sleep
      @backoff_setup = { type: :constant, start: @start }
      @backoff_intervals = Backoff.new(*@backoff_setup.values).intervals
      # Overwriting the defaults
      validate_options(options, &setter)
    end

    def to_hash
      CONFIG_ATTRS.each_with_object({}) do |key, hash|
        hash[key] = public_send(key)
      end
    end

    def [](value)
      public_send(value)
    end

    def validate_options(options)
      options.each do |k, v|
        raise ArgumentError, "#{k} is not a valid configuration" unless CONFIG_ATTRS.include?(k)
        case k
        when :retries
          raise ArgumentError, "#{k} must be positive integer" unless v.is_a?(Integer) && v.positive?
        when :time_to_sleep
          raise ArgumentError, "#{k} must be positive number" unless (v.is_a?(Integer) || v.is_a?(Float)) && v >= 0
        when :retriable
          raise ArgumentError, "#{k} must be array of retriable errors" unless v.is_a?(Array)
        when :retry_proc, :retry_condition_proc
          raise ArgumentError, "#{k} must be Proc" unless v.is_a?(Proc)
        when :backoff_setup
          available_types = [:constant, :linear, :fibonacci, :exponential]
          raise ArgumentError, 'Incorrect backoff type' unless available_types.include?(v[:type])
        end
        yield(k, v) if block_given?
      end
    end

    def setter
      ->(key, value) {
        if key == :backoff_setup
          assign_backoff_intervals(value)
        else
          public_send("#{key}=", value)
        end
      }
    end

    def assign_backoff_intervals(backoff_setup)
      @backoff_intervals = Backoff.new(backoff_setup[:type], backoff_setup[:start]).intervals
    end
  end
end
