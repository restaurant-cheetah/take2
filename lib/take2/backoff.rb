# frozen_string_literal: true

module Take2
  class Backoff
    BACKOFF_ATTRS = [:type, :start, :retries, :factor, :intervals].freeze
    attr_reader(*BACKOFF_ATTRS)
    def initialize(type, start = 1, factor = 1, retries = 10)
      @type = type
      @start = start.to_i
      @retries = retries
      @factor = factor
      @intervals = intervals_table
    end

    private

    def intervals_table
      send(type)
    end

    def constant
      Array.new(retries, start)
    end

    def linear
      (start...(retries + start)).map { |i| i * factor }
    end

    def fibonacci
      (1..20).map { |i| fibo(i) }.partition { |x| x >= start }.first.take(retries)
    end

    def exponential
      (1..20).each_with_index.inject([]) do |memo, (el, ix)|
        memo << if ix == 0
          start
        else
          (2**el - 1) + rand(1..2**el)
        end
      end.take(retries)
    end

    def fibo(n, memo = {})
      return n if n < 2
      memo[n] ||= fibo(n - 1, memo) + fibo(n - 2, memo)
    end
  end
end
