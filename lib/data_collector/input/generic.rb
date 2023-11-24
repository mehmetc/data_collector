require 'bunny_burrow'
require_relative '../ext/base'
require 'listen'
require 'active_support/core_ext/hash'

module DataCollector
  class Input
    class Generic
      def initialize(uri, options = {})
        @uri = URI(URI.decode_uri_component(uri.to_s)) #"#{uri.scheme}://#{URI.decode_uri_component(uri.host)}#{URI.decode_uri_component(uri.path)}"
        @options = options
        @running = false

        @input = DataCollector::Input.new
        @output = DataCollector::Output.new

        @name = options[:name] || "input-#{Time.now.to_i}-#{rand(10000)}"
        create_listener
      end

      def run(should_block = false, &block)
        raise DataCollector::Error, 'Please supply a on_message block' if @on_message_callback.nil?
        @running = true

        if should_block
          while running?
            yield block if block_given?
            sleep 2
          end
        else
          yield block if block_given?
        end

      end

      def stop
        @listener.stop
      end

      def pause
        @listener.pause
      end

      def running?
        @running
      end

      def stopped?
        @running == false
      end

      def paused?
        @listener.paused?
      end

      def on_message(&block)
        @on_message_callback = block
      end

      private

      def create_listener
        raise DataCollector::Error, 'Please implement a listener'
      end

      def handle_on_message(input, output, data)
        if (callback = @on_message_callback)
          timing = Time.now
          begin
            callback.call(input, output, data)
          rescue StandardError => e
            DataCollector::Core.error("INPUT #{e.message}")
            puts e.backtrace.join("\n")
          ensure
            DataCollector::Core.log("INPUT ran for #{((Time.now.to_f - timing.to_f).to_f * 1000.0).to_i}ms")
          end
        end
      end

    end
  end
end