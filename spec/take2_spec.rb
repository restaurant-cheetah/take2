require 'spec_helper'

RSpec.describe Take2 do

  let!(:config) do
    Take2.configure do |c|
      c.retries               = 1
      c.retriable             = [Net::HTTPServerError, Net::HTTPRetriableError].freeze
      c.retry_condition_proc  = proc {false}
      c.retry_proc            = proc {}
      c.time_to_sleep         = 0.5
    end
  end
  let(:klass)   { Class.new { include Take2 } }
  let(:object)  { klass.new }

  describe 'default values' do

    subject { klass.retriable_configuration }

    it 'has a default value for :retries' do
      expect(subject[:retries]).to eql described_class.configuration[:retries]
    end

    it 'has a default value for :retriable' do
      expect(subject[:retriable]).to eql described_class.configuration[:retriable]
    end

    it 'has a default value for :retry_condition_proc' do
      expect(subject[:retry_condition_proc].call).to eql described_class.configuration[:retry_condition_proc].call
    end

    it 'has a default value for :retry_proc' do
      expect(subject[:retry_proc].call).to eql described_class.configuration[:retry_proc].call
    end

    it 'has a default value for :time_to_sleep' do
      expect(subject[:time_to_sleep]).to eql described_class.configuration[:time_to_sleep]
    end

  end

  describe 'included class helpers' do

    subject { klass.retriable_configuration }

    describe '.number_of_retries' do

      context 'with valid argument' do

        it 'sets the :retries attribute' do
          klass.number_of_retries 1
          expect(subject[:retries]).to eql 1
        end

      end

      context 'with invalid argument' do

        it 'raises ArgumentError' do
          expect { klass.number_of_retries 0 }.to raise_error ArgumentError
        end

      end

    end

    describe '.retriable_errors' do

      context 'with valid argument' do

        it 'sets the :retriable_errors attribute' do
          retriables = IOError
          klass.retriable_errors retriables
          expect(subject[:retriable]).to eql [retriables]
        end

      end

      context 'with invalid argument' do

        it 'raises ArgumentError' do
          class Klass; end
          expect { klass.retriable_errors Klass }.to raise_error ArgumentError
        end

      end

    end

    describe '.retriable_condition' do

      context 'with valid argument' do

        it 'sets the :retriable_condition attribute' do
          retriable_proc = proc { 'Ho-Ho-Ho' }
          klass.retriable_condition retriable_proc
          expect(subject[:retry_condition_proc].call).to eql retriable_proc.call
        end

      end

      context 'with invalid argument' do

         it 'raises ArgumentError' do
          expect { klass.retriable_condition Class.new }.to raise_error ArgumentError
         end

      end

    end

    describe '.on_retry' do

      context 'with valid argument' do

        it 'sets the :on_retry attribute' do
          retry_proc = proc { |el| el }
          klass.on_retry retry_proc
          expect(subject[:retry_proc].call).to eql retry_proc.call
        end

      end  

      context 'with invalid argument' do

        it 'raises ArgumentError' do
          expect { klass.on_retry Class.new }.to raise_error ArgumentError
        end

      end

    end

    describe '.sleep_before_retry' do

      context 'with valid argument' do

        it 'sets the :sleep_before_retry attribute' do
          klass.sleep_before_retry 3.5
          expect(subject[:time_to_sleep]).to eql 3.5
        end

      end
      
      context 'with invalid argument' do

        it 'raises ArgumentError' do
          expect { klass.sleep_before_retry -1 }.to raise_error ArgumentError
        end

      end

    end

  end

  describe '.call_api_with_retry' do

    def increment_retry_counter
      @tries += 1
    end

    def wrath_the_gods_with(error)
      increment_retry_counter
      raise error
    end

    context 'when raised with non retriable error' do

      let(:error) { StandardError.new 'Release the Kraken!!' }

      before(:each) { @tries = 0 }

      it 're raises the original error' do
        expect do
          object.call_api_with_retry { wrath_the_gods_with error }
        end.to raise_error error.class
      end

      it 'is not retried' do
        expect do
          object.call_api_with_retry { wrath_the_gods_with error } rescue nil
        end.to change{@tries}.from(0).to(1)
      end

      # it 'logs the error' do
      #   expect(object).to receive(:log_error).with(error)
      #   object.call_api_with_retry { wrath_the_gods_with error } rescue nil
      # end

    end

    context 'when raised with retriable error' do

      let(:retriable_error) {  Net::HTTPRetriableError.new 'Release the Kraken...many times!!', nil }

      before(:each) { @tries = 0 }

      it 'retries correct number of times' do
        expect do
          object.call_api_with_retry { wrath_the_gods_with retriable_error } rescue nil
        end.to change {@tries}.from(0).to(klass.retriable_configuration[:retries] + 1)
      end

      it 'calls the retry proc' do
        expect(klass.retriable_configuration[:retry_proc]).to receive(:call).exactly(klass.retriable_configuration[:retries])
        object.call_api_with_retry { wrath_the_gods_with retriable_error } rescue nil
      end

      it 'calls the retry_condition proc' do
        expect(klass.retriable_configuration[:retry_condition_proc]).to receive(:call).exactly(klass.retriable_configuration[:retries])
        object.call_api_with_retry { wrath_the_gods_with retriable_error } rescue nil
      end

      it 'sleeps the correct amount of time' do
        allow_any_instance_of(Object).to receive(:sleep).with(klass.retriable_configuration[:time_to_sleep])
        object.call_api_with_retry { wrath_the_gods_with retriable_error } rescue nil
      end

      # it 'logs the error' do
      #   expect(object).to receive(:log_error).with(retriable_error)
      #   object.call_api_with_retry { wrath_the_gods_with retriable_error } rescue nil
      # end

      it 're raises the original error' do
        expect do
          object.call_api_with_retry { wrath_the_gods_with retriable_error }
        end.to raise_error retriable_error.class
      end

    end

    context 'with custom options' do

      let(:retriable_error)     { Net::HTTPRetriableError.new 'Release the Kraken...many times!!', nil }
      let(:new_retriable_error) { IOError.new 'You shall not PASS!' }

      before(:each) { @tries = 0 }
        
      it 'overwrites the :retries' do
        expect do
          object.call_api_with_retry(retries: 3) { wrath_the_gods_with retriable_error } rescue nil
        end.to change { @tries }.from(0).to(4)
      end

      it 'overwrites the :retry_proc' do
        new_proc = proc { 1**1 }
        expect(new_proc).to receive(:call).exactly(klass.retriable_configuration[:retries])
        object.call_api_with_retry(retry_proc: new_proc) { wrath_the_gods_with retriable_error } rescue nil          
      end

      it 'overwrites the :retry_condition_proc' do
        new_proc = proc { true }
        expect(new_proc).to receive(:call).exactly(klass.retriable_configuration[:retries])
        object.call_api_with_retry(retry_condition_proc: new_proc) { wrath_the_gods_with retriable_error } rescue nil          
      end

      it 'overwrites the :time_to_sleep' do
        allow_any_instance_of(Object).to receive(:sleep).with(1.66)
        object.call_api_with_retry(time_to_sleep: 1.66) { wrath_the_gods_with retriable_error } rescue nil
      end

      it 'overwrites the :retriable' do
        expect do                
          object.call_api_with_retry(retriable: [new_retriable_error]) { wrath_the_gods_with retriable_error } rescue nil
        end.to change { @tries }.from(0).to(1)
      end

    end

  end

end