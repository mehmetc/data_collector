require_relative './generic'

module DataCollector
  class Output
    class Rpc < Generic
      def initialize(uri, options = {})
        super
      end

      def send(message)
        raise DataCollector::Error, "No client found" if @producer.nil? || stopped?
        JSON.parse(@producer.publish(message, @bunny_queue))
      end

      def stop
        if @producer && @running
          @running = false
          @producer.shutdown
        end
      end

      private
      def create_producer(log = false)
        @producer ||= BunnyBurrow::Client.new do |client|
          parse_uri
          client.rabbitmq_url = @bunny_uri.to_s
          client.rabbitmq_exchange = @bunny_channel
          #client.connection_name = @name

          client.logger = DataCollector::Core.logger if log
          @running = true
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
