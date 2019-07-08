# encoding: utf-8
require 'logger'
require_relative 'core'

module DataCollector
  class Runner
    def initialize(logger = Logger.new(STDOUT))
      Encoding.default_external = 'UTF-8'
      @logger = logger
    end

    def run(rule_file_name = nil)
      @time_start = Time.now
      prg = self
      if block_given?
        a = Class.new do
          include DataCollector::Core
        end.new

        yield a
      elsif !rule_file_name.nil?
        prg.instance_eval(File.read(rule_file_name))
      else
        @logger.error('Please supply a block or file')
      end

      prg
    rescue Error => e
      puts e.message
      puts e.backtrace.join("\n")
    ensure
#    output.tar_file.close unless output.tar_file.closed?
      @logger.info("Finished in #{((Time.now - @time_start)*1000).to_i} ms")
    end

    private
    include DataCollector::Core
  end
end