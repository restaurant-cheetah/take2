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

    def call_api_with_retry
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
        log_error e
        raise e
      end
    end

    def log_error(error)
      Rails.logger.warn error
    end
  end

  module ClassMethods

    def number_of_retries(num)
      self.retries = num
    end

    def retriable_errors(*errors)
      self.retriable = errors
    end

    def retriable_condition(proc)
      self.retry_condition_proc = proc
    end

    def on_retry(proc)
      self.retry_proc = proc
    end

    def sleep_before_retry(seconds)
      self.time_to_sleep = seconds
    end

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

    def log_client_error(error, tries)
      Rails.logger.warn "#{self.name} - Retrying.. #{tries} of #{self.retries} (#{error})"
    end

  end

end