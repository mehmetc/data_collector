require 'iso8601'

module DataCollector
  class Pipeline
    attr_reader :run_count, :name
    def initialize(options = {})
      @running = false
      @paused = false

      @input = DataCollector::Input.new
      @output = DataCollector::Output.new
      @run_count = 0

      @schedule = options[:schedule] || {}
      @name = options[:name] || "#{Time.now.to_i}-#{rand(10000)}"
      @options = options
      @listeners = []
    end

    def on_message(&block)
      @on_message_callback = block
    end

    def run
      if paused? && @running
        @paused = false
        @listeners.each do |listener|
          listener.run if listener.paused?
        end
      end

      @running = true
      if @schedule && !@schedule.empty?
        while running?
          @run_count += 1
          start_time = ISO8601::DateTime.new(Time.now.to_datetime.to_s)
          begin
            duration = ISO8601::Duration.new(@schedule)
          rescue StandardError => e
            raise DataCollector::Error, "PIPELINE - bad schedule: #{e.message}"
          end
          interval = ISO8601::TimeInterval.from_duration(start_time, duration)

          DataCollector::Core.log("PIPELINE running in #{interval.size} seconds")
          sleep interval.size
          handle_on_message(@input, @output) unless paused?
        end
      else # run once
        @run_count += 1
        if @options.key?(:uri)
          listener = Input.new.from_uri(@options[:uri], @options)
          listener.on_message do |input, output, filename|
            DataCollector::Core.log("PIPELINE triggered by #{filename}")
            handle_on_message(@input, @output, filename)
          end
          @listeners << listener

          listener.run(true)

        else
          DataCollector::Core.log("PIPELINE running once")
          handle_on_message(@input, @output)
        end
      end
    rescue StandardError => e
      DataCollector::Core.error("PIPELINE run failed: #{e.message}")
      raise e
      #puts e.backtrace.join("\n")
    end

    def stop
      @running = false
      @paused = false
      @listeners.each do |listener|
        listener.stop if listener.running?
      end
    end

    def pause
      if @running
      @paused = !@paused
        @listeners.each do |listener|
          listener.pause if listener.running?
        end
      end
    end

    def running?
      @running
    end

    def stopped?
      !@running
    end

    def paused?
      @paused
    end

    private

    def handle_on_message(input, output, filename = nil)
      if (callback = @on_message_callback)
        timing = Time.now
        begin
          callback.call(input, output, filename)
        rescue StandardError => e
          DataCollector::Core.error("PIPELINE #{e.message}")
        ensure
          DataCollector::Core.log("PIPELINE ran for #{((Time.now.to_f - timing.to_f).to_f * 1000.0).to_i}ms")
        end
      end
    end

  end
end