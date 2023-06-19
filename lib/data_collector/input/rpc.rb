require_relative 'generic'
require 'bunny'
require 'active_support/core_ext/hash'
require 'ostruct'
require 'securerandom'
require 'thread'

module DataCollector
  class Input
    class Rpc < Generic
      def initialize(uri, options = {})
        super

        if running?
          create_queue unless @queue
        end
      end

      def running?
        @listener.open?
      end

      def send(reply_to, message)
        correlation_id = SecureRandom.uuid
        if running?
          @exchange.publish(message,
                            routing_key: reply_to,
                            correlation_id: correlation_id)
        end
      end

      private

      def create_exchange
        @exchange ||= begin
                        create_channel
                        @channel.topic(@bunny_channel, auto_delete: true)
                      end
      end
      def create_listener
        parse_uri

        @listener ||= begin
                        connection = Bunny.new(@bunny_uri.to_s)
                        connection.start

                        connection
                      rescue StandardError => e
                        raise DataCollector::Error, "Unable to connect to RabbitMQ. #{e.message}"
                      end
      end

      def create_channel
        create_listener
        raise DataCollector::Error, 'Connection to RabbitMQ is closed' if @listener.closed?
        @channel ||= @listener.create_channel
      end

      def create_queue
        @queue ||= begin
                     create_exchange
                     queue = @channel.queue(@bunny_queue).bind(@exchange, routing_key: "#{@bunny_queue}.#")

                     queue.subscribe(consumer_tag: @name) do |delivery_info, metadata, payload|
                       handle_on_message(@input, @output, OpenStruct.new(info: delivery_info, properties: metadata, body: payload))
                     end if queue

                     queue
                   end
      end

      def parse_uri
        raise 'URI must be of format rpc+amqp://user:password@host/exchange/queue' unless @uri.path =~ /\// && @uri.path.split('/').length == 3

        @bunny_channel = @uri.path.split('/')[1]
        @bunny_queue   = @uri.path.split('/')[2]
        @bunny_uri = @uri.clone
        @bunny_uri.path=''
        @bunny_uri.scheme='amqp'
      end
    end
  end
end