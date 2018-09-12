require 'net/http'

require 'take2/version'
require 'take2/configuration'

module Take2

  def self.included(base)
    base.extend ClassMethods
    base.send :set_defaults
    base.send :include, InstanceMethods
  end

  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset(options = {})
    @configuration = Configuration.new(options)
  end

  def self.configure
    yield(configuration) if block_given?
  end

  module InstanceMethods

    # Yields a block and retries on retriable errors n times.
    # The raised error could be the defined retriable or it child.

    #
    # Example:
    #   class KatorzaService
    #     include Take2
    #
    #     number_of_retries 3
    #     retriable_errors Net::HTTPRetriableError, Net::HTTPServerError
    #     retriable_condition proc { |error| response_status(error.response) < 500 }
    #     on_retry proc do |error, tries|
    #       puts "#{self.class.name} - Retrying.. #{tries} of #{self.class.retriable_configuration[:retries]} (#{error})"
    #     end
    #     sleep_before_retry 3
    #
    #     def give_me_food
    #       call_with_retry do
    #         # Some logic that might raise..
    #         # If it will raise retriable, magic happens.
    #         # If not the original error re raised
    #       end
    #     end
    #
    #   end
    def call_with_retry
      config = self.class.retriable_configuration
      tries ||= config[:retries]
      begin
        yield
      rescue => e
        if config[:retriable].map {|klass| e.class <= klass }.any?
          unless tries.zero? || config[:retry_condition_proc]&.call(e)
            config[:retry_proc]&.call(e, tries)
            sleep(config[:time_to_sleep]) if config[:time_to_sleep]
            tries -= 1
            retry
          end
        end        
        raise e
      end
    end
    
  end

  module ClassMethods
    # Sets number of retries.
    #
    # Example:
    #   class KatorzaService
    #     include Take2
    #     number_of_retries 3
    #   end
    # Arguments:
    #   num: Positive integer
    def number_of_retries(num)
      raise ArgumentError, 'Must be positive Integer' unless num.is_a?(Integer) && num.positive?
      self.retries = num
    end

    # Sets list of errors on which the block will retry.
    #
    # Example:
    #   class KatorzaService
    #     include Take2
    #     retriable_errors Net::HTTPRetriableError, Errno::ECONNRESET
    #   end
    # Arguments:
    #   errors: List of retiable errors
    def retriable_errors(*errors)
      self.retriable = errors
    end

    # Sets condition for retry attempt. 
    # If set, it MUST result to +false+ with number left retries greater that zero in order to retry.
    #
    # Example:
    #   class KatorzaService
    #     include Take2
    #     retriable_condition proc { |error| error.response.status_code < 500 }
    #   end
    # Arguments:
    #   proc: Proc. The +proc+ called by default with the raised error argument
    def retriable_condition(proc)
      raise ArgumentError, 'Must be callable' unless proc.respond_to?(:call)
      self.retry_condition_proc = proc
    end

    # Defines a proc that is called *before* retry attempt. 
    #
    # Example:
    #   class KatorzaService
    #     include Take2
    #     on_retry proc { |error, tries| puts "Retrying.. #{tries} of #{self.class.retriable_configuration[:retries]}" }
    #   end
    # Arguments:
    #   proc: Proc. The +proc+ called by default with the raised error and number of left retries.
    def on_retry(proc)
      raise ArgumentError, 'Must be callable' unless proc.respond_to?(:call)
      self.retry_proc = proc
    end

    # Sets number of seconds to sleep before next retry.
    #
    # Example:
    #   class KatorzaService
    #     include Take2
    #     sleep_before_retry 1.5
    #   end
    # Arguments:
    #   seconds: Positive number.
    def sleep_before_retry(seconds)
      raise ArgumentError, 'Must be positive numer' unless (seconds.is_a?(Integer) || seconds.is_a?(Float)) && seconds.positive?
      self.time_to_sleep = seconds
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
      return response.status if response.respond_to? :status
      response.status_code if response.respond_to? :status_code
    end

  end

end