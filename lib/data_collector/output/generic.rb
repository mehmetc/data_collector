require 'bunny_burrow'
require_relative '../ext/base'
require 'json'
require 'active_support/core_ext/hash'

module DataCollector
  class Output
    class Generic
      def initialize(uri, options = {})
        @uri = uri
        @options = options
        @running = false

        @name = options[:name] || "output-#{Time.now.to_i}-#{rand(10000)}"
        create_producer
      end

      def send(message)
        raise DataCollector::Error, 'Please implement a producer'
      end

      def running?
        @running
      end

      def stopped?
        @running == false
      end

      def stop
        @running = false
      end

      private
      def create_producer(log = false)
        raise DataCollector::Error, 'Please implement a producer'
      end

    end
  end
end
