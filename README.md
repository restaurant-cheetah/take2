## Take2
[![CircleCI](https://circleci.com/gh/restaurant-cheetah/take2/tree/master.svg?style=shield)](https://circleci.com/gh/restaurant-cheetah/take2/tree/master)
![Gem](https://img.shields.io/gem/dt/take2.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/restaurant-cheetah/take2.svg)
![Gem](https://img.shields.io/gem/v/take2.svg)  
Define rules for retrying behavior.  
Yield block of code into the public api of the take2.  
Things getting take two :)

## Install

```ruby
gem install take2
```
## Examples

```ruby
class KratosService
  include Take2

  
  number_of_retries 3
  
  # Could be configured globally or on class level.
  retriable_errors Net::HTTPRetriableError, Net::HTTPServerException

  # Retry unless the response status is 5xx. The implementation is dependent of the http lib in use.
  retriable_condition proc { |error| error.response.code < 500 }

  # Defines callable code to run before next retry. Could be an out put to some logger.
  on_retry proc { |error, tries| puts "#{self.name} - Retrying.. #{tries} of #{self.retriable_configuration[:retries]} (#{error})" }
       
  sleep_before_retry 3.3

  def call_boy
    call_api_with_retry do
      # Some logic that might raise..
      # If it will raise retriable, magic happens.
      # If not the original error re raised

      raise Net::HTTPRetriableError.new 'Release the Kraken...many times!!', nil
    end
  end

  # Pass custom options per method call
  # The class defaults will not be overwritten
  def kill_baldur
    call_api_with_retry(retries: 2, retriable: [IOError], retry_proc: proc {}, retry_condition_proc: proc {}, time_to_sleep: 1.11) do
      # Some logic that might raise..
    end
  end

end  

KratosService.new.call_boy
#=> KratosService - Retrying.. 3 of 3 (Release the Kraken...many times!!)
#=> KratosService - Retrying.. 2 of 3 (Release the Kraken...many times!!)
#=> KratosService - Retrying.. 1 of 3 (Release the Kraken...many times!!)
# After the retrying is done, original error re-raised  
#=> Net::HTTPRetriableError: Release the Kraken...many times!!

# Not wrapping with method
KratosService.new.call_api_with_retry { 1 / 0 }

# Or..
Class.new { include Take2 }.new.call_api_with_retry { 1 / 0 }


# Current configuration hash
KratosService.retriable_configuration

```

## Configurations
#### could be implemented as rails initializer

```ruby
# config/initializers/take2.rb

Take2.configure do |config|
  config.retries    = 3
  config.retriable  = [      
      Net::HTTPServerException,
      Net::HTTPRetriableError,      
      Errno::ECONNRESET,
      IOError
  ].freeze
  config.retry_condition_proc = proc {false}
  config.time_to_sleep        = nil
  config.retry_proc           = proc {Rails.logger.info "Retry message"}
end
```