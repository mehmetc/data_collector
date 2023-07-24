require_relative 'generic'
require 'listen'

module DataCollector
  class Input
    class Dir < Generic
      def initialize(uri, options = {})
        super
      end

      def run(should_block = false, &block)
        @listener.start unless running?
        if block_given?
          while should_block && !paused?
            yield
          end
        else
          sleep if should_block && running? && !paused?
        end
      end

      def running?
        @listener.processing?
      end

      private

      def create_listener
        absolute_path = File.absolute_path("#{@uri.host}#{@uri.path}")
        raise DataCollector::Error, "#{@uri.to_s} not found" unless File.exist?(absolute_path)

        @listener ||= Listen.to(absolute_path, @options) do |modified, added, _|
          files = added | modified
          files.each do |filename|
            handle_on_message(@input, @output, filename)
          end
        end
      end

    end
  end
end