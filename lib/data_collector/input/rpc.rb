require_relative 'generic'

module DataCollector
  class Input
    class Rpc < Generic
      def initialize(uri, options = {})
        super
      end

      def running?
        @running
      rescue StandardError => e
        DataCollector::Core.error(e.message)
      end

      def stop
        if running?
          @listener.shutdown
          @running = false
        end
      rescue StandardError => e
        DataCollector::Core.error(e.message)
      end

      def pause
        raise "PAUSE not implemented."
      rescue StandardError => e
        DataCollector::Core.error(e.message)
      end



      def run(should_block = false, &block)
          @listener.subscribe(@bunny_queue) do |payload|
            payload = JSON.parse(payload)
            response = BunnyBurrow::Server.create_response
            response[:data] = handle_on_message(@input, @output, payload)

            response
          end
          @running = true

          if should_block
            while running?
              yield block if block_given?
              @listener.wait
            end
          else
            yield block if block_given?
          end
      rescue StandardError => e
        DataCollector::Core.error(e.message)
      end

      private
      def create_listener(log = false)
        @listener ||= BunnyBurrow::Server.new do |server|
          parse_uri
          server.rabbitmq_url = @bunny_uri.to_s
          server.rabbitmq_exchange = @bunny_channel

          server.connection_name = @name
          server.logger = DataCollector::Core.logger if log
        end

        @listener
      rescue StandardError => e
        DataCollector::Core.error(e.message)
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