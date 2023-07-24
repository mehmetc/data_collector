require_relative 'generic'
require 'listen'

module DataCollector
  class Input
    class Dir < Generic
      def initialize(uri, options = {})
        super
      end

      def run(should_block = false, &block)
        @listener.start
        sleep if should_block
      end

      def running?
        @listener.processing?
      end

      private

      def create_listener
        @listener ||= Listen.to("#{@uri.host}#{@uri.path}", @options) do |modified, added, _|
          files = added | modified
          files.each do |filename|
            handle_on_message(@input, @output, filename)
          end
        end
      end

    end
  end
end