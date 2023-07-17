require_relative 'generic'
require 'bunny'
require 'active_support/core_ext/hash'
require 'ostruct'

module DataCollector
  class Input
    class Queue < Generic
      def initialize(uri, options = {})
        super

        if running?
          create_queue unless @queue
        end
      end

      def running?
        @listener.open?
      end

      def send(route, message)
        if running?
          @exchange.publish(message, routing_key: route)
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

      def create_exchange
        @exchange ||= begin
                        options = CGI.parse(@uri.query).with_indifferent_access
                        raise DataCollector::Error, '"channel" query parameter missing from uri.' unless options.include?(:channel)
                        create_channel
                        @channel.topic(options[:channel].first, auto_delete: true)
                      end
      end

      def create_channel
        raise DataCollector::Error, 'Connection to RabbitMQ is closed' if @listener.closed?
        @channel ||= @listener.create_channel
      end

      def create_queue
        @queue ||= begin
                     options = CGI.parse(@uri.query).with_indifferent_access
                     raise DataCollector::Error, '"queue" query parameter missing from uri.' unless options.include?(:queue)
                     create_exchange
                     queue = @channel.queue(options[:queue].first, auto_delete: true).bind(@exchange, routing_key: "#{options[:queue].first}.#")

                     queue.subscribe(consumer_tag: @name) do |delivery_info, metadata, payload|
                       handle_on_message(@input, @output, OpenStruct.new(info: delivery_info, properties: metadata, body: payload))
                     end if queue

                     queue
                   end
      end
    end
  end
end