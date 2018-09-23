require 'spec_helper'

RSpec.describe Take2::Configuration do

  describe 'default configurations' do

    let(:default) { described_class.new }

    it 'has correct default value for retries' do
      expect(default.retries).to eql 3
    end

    it 'has correct default retriable errors array' do
      expect(default.retriable).to eql [
        Net::HTTPServerError,
        Net::HTTPServerException,
        Net::HTTPRetriableError,        
        Errno::ECONNRESET,
        IOError,
       ].freeze
    end

    it 'has default proc for retry_proc' do
      p = proc {}
      expect(default.retry_proc.call).to eql p.call
    end

    it 'has default proc for retry_condition_proc' do
      p = proc {false}
      expect(default.retry_condition_proc.call).to eql p.call
    end

    it 'has correct default value for time_to_sleep' do
      expect(default.time_to_sleep).to eql 3
    end

  end

  describe 'overwriting the default configurations' do

    context 'with valid hash' do

      let!(:new_configs_hash) { 
        {
          retries: 2,
          retriable: [Net::HTTPRetriableError],
          retry_condition_proc: proc { true },
          retry_proc: proc { 2*2 },
          time_to_sleep: 0
        }
      }

      let!(:new_configuration) { described_class.new(new_configs_hash).to_hash }

      [:retries, :retriable, :retry_proc, :retry_condition_proc, :time_to_sleep].each do |key|
        it "sets the #{key} key" do
          if new_configs_hash[key].respond_to?(:call)
            expect(new_configuration[key].call).to eql new_configs_hash[key].call
          else  
            expect(new_configuration[key]).to eql new_configs_hash[key]
          end
        end
      end

    end

    context 'with invalid hash' do

      context 'when retries set to invalid value' do

        it 'raises ArgumentError' do

          expect { described_class.new(retries: -1) }.to raise_error ArgumentError
          expect { described_class.new(retries: 0) }.to raise_error ArgumentError

        end

      end

      context 'when time_to_sleep set to invalid value' do

        it 'raises ArgumentError' do

          expect { described_class.new(time_to_sleep: -1) }.to raise_error ArgumentError
          
        end

      end

      context 'when retriable set to invalid value' do

        it 'raises ArgumentError' do

          expect { described_class.new(retriable: StandardError) }.to raise_error ArgumentError
          
        end

      end

      context 'when retry_proc set to invalid value' do

        it 'raises ArgumentError' do

          expect { described_class.new(retry_proc: {}) }.to raise_error ArgumentError
          
        end

      end

      context 'when retry_condition_proc set to invalid value' do

        it 'raises ArgumentError' do

          expect { described_class.new(retry_condition_proc: {}) }.to raise_error ArgumentError
          
        end

      end
      
    end

  end


end