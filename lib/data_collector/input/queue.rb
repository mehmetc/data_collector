require_relative 'generic'
require 'bunny'
require 'active_support/core_ext/hash'

module DataCollector
  class Input
    class Queue < Generic
      def initialize(uri, options)
        super

        if running?
          create_channel unless @channel
          create_queue unless @queue
        end
      end

      def running?
        @listener.open?
      end

      def send(message)
        if running?
          @queue.publish(message)
        end
      end

      private

      def create_listener
        @listener ||= begin
                        connection = Bunny.new(@uri.to_s)
                        connection.start

                        connection
                      rescue StandardError => e
                        raise DataCollector::Error, "Unable to connect to RabbitMQ. #{e.message}"
                      end
      end

      def create_channel
        raise DataCollector::Error, 'Connection to RabbitMQ is closed' if @listener.closed?
        @channel ||= @listener.create_channel
      end

      def create_queue
        @queue ||= begin
                     options = CGI.parse(@uri.query).with_indifferent_access
                     raise DataCollector::Error, '"channel" query parameter missing from uri.' unless options.include?(:channel)
                     queue = @channel.queue(options[:channel].first)

                     queue.subscribe do |delivery_info, metadata, payload|
                       handle_on_message(input, output, payload)
                     end if queue

                     queue
                   end
      end
    end
  end
end