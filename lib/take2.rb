# frozen_string_literal: true

require 'net/http'
require 'take2/version'
require 'take2/configuration'

module Take2
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:set_defaults)
    base.send(:include, InstanceMethods)
  end

  class << self
    attr_accessor :configuration

    def config
      @configuration ||= Configuration.new
    end

    def reset(options = {})
      @configuration = Configuration.new(options)
    end

    def local_defaults(options)
      configuration.validate_options(options)
    end

    def configure
      yield(config) if block_given?
    end
  end

  module InstanceMethods
    # Yields a block and retries on retriable errors n times.
    # The raised error could be the defined retriable or it child.
    #
    # Example:
    #   class PizzaService
    #     include Take2
    #
    #     number_of_retries 3
    #     retriable_errors Net::HTTPRetriableError
    #     retriable_condition proc { |error| response_status(error.response) < 500 }
    #     on_retry proc { |error, tries|
    #       puts "#{self.name} - Retrying.. #{tries} of #{self.retriable_configuration[:retries]} (#{error})"
    #     }
    #     backoff_strategy type: :exponential, start: 3
    #
    #     def give_me_food
    #       with_retry do
    #         # Some logic that might raise..
    #         # If it will raise retriable, magic happens.
    #         # If not the original error re raised
    #       end
    #     end
    #
    #   end
    def call_api_with_retry(options = {}, &block)
      self.class.call_api_with_retry(options, &block)
    end

    alias_method :with_retry, :call_api_with_retry
  end

  module ClassMethods
    def call_api_with_retry(options = {})
      config = retriable_configuration
      config.merge!(Take2.local_defaults(options)) unless options.empty?
      tries ||= config[:retries]
      begin
        yield
      rescue => e
        if config[:retriable].map { |klass| e.class <= klass }.any?
          unless tries.zero? || config[:retry_condition_proc]&.call(e)
            config[:retry_proc]&.call(e, tries)
            rest(config, tries)
            tries -= 1
            retry
          end
        end
        raise e
      end
    end

    alias_method :with_retry, :call_api_with_retry

    # Sets number of retries.
    #
    # Example:
    #   class PizzaService
    #     include Take2
    #     number_of_retries 3
    #   end
    # Arguments:
    #   num: integer
    def number_of_retries(num)
      raise ArgumentError, 'Must be positive Integer' unless num.is_a?(Integer) && num.positive?
      self.retries = num
    end

    # Sets list of errors on which the block will retry.
    #
    # Example:
    #   class PizzaService
    #     include Take2
    #     retriable_errors Net::HTTPRetriableError, Errno::ECONNRESET
    #   end
    # Arguments:
    #   errors: List of retiable errors
    def retriable_errors(*errors)
      message = 'All retriable errors must be StandardError decendants'
      raise ArgumentError, message unless errors.all? { |e| e <= StandardError }
      self.retriable = errors
    end

    # Sets condition for retry attempt.
    # If set, it MUST result to +false+ with number left retries greater that zero in order to retry.
    #
    # Example:
    #   class PizzaService
    #     include Take2
    #     retriable_condition proc { |error| error.response.status_code < 500 }
    #   end
    # Arguments:
    #   proc: Proc. The proc called by default with the raised error argument
    def retriable_condition(proc)
      raise ArgumentError, 'Must be callable' unless proc.respond_to?(:call)
      self.retry_condition_proc = proc
    end

    # Defines a proc that is called *before* retry attempt.
    #
    # Example:
    #   class PizzaService
    #     include Take2
    #     on_retry proc { |error, tries| puts "Retrying.. #{tries} of #{self.class.retriable_configuration[:retries]}" }
    #   end
    # Arguments:
    #   proc: Proc. The proc called by default with the raised error and number of left retries.
    def on_retry(proc)
      raise ArgumentError, 'Must be callable' unless proc.respond_to?(:call)
      self.retry_proc = proc
    end

    def sleep_before_retry(seconds)
      unless (seconds.is_a?(Integer) || seconds.is_a?(Float)) && seconds.positive?
        raise ArgumentError, 'Must be positive numer'
      end
      puts "DEPRECATION MESSAGE - The sleep_before_retry method is softly deprecated in favor of backoff_stategy \r
       where the time to sleep is a starting point on the backoff intervals. Please implement it instead."
      self.time_to_sleep = seconds
    end

    # Sets the backoff strategy
    #
    # Example:
    #   class PizzaService
    #     include Take2
    #     backoff_strategy type: :exponential, start: 3
    #   end
    # Arguments:
    #   hash: object
    def backoff_strategy(options)
      available_types = [:constant, :linear, :fibonacci, :exponential]
      raise ArgumentError, 'Incorrect backoff type' unless available_types.include?(options[:type])
      self.backoff_intervals = Backoff.new(options[:type], options[:start]).intervals
    end

    # Exposes current class configuration
    def retriable_configuration
      Take2::Configuration::CONFIG_ATTRS.each_with_object({}) do |key, hash|
        hash[key] = send(key)
      end
    end

    private

    attr_accessor(*Take2::Configuration::CONFIG_ATTRS)

    def set_defaults
      config = Take2.configuration.to_hash
      Take2::Configuration::CONFIG_ATTRS.each do |attr|
        instance_variable_set("@#{attr}", config[attr])
      end
    end

    def response_status(response)
      return response.status if response.respond_to?(:status)
      response.status_code if response.respond_to?(:status_code)
    end

    def rest(config, tries)
      seconds = if config[:time_to_sleep].to_f > 0
        config[:time_to_sleep].to_f
      else
        next_interval(config[:backoff_intervals], config[:retries], tries)
      end
      sleep(seconds)
    end

    def next_interval(intervals, retries, current)
      intervals[retries - current]
    end
  end
end
