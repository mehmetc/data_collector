# encoding: utf-8
require 'jsonpath'
require 'proxy_logger'

require_relative 'input'
require_relative 'output'
require_relative 'rules'
require_relative 'rules_ng'
require_relative 'config_file'

module DataCollector
  module Core
    # Pipeline for your data pipeline
    # example:  pipeline.on_message do |input, output|
    #            ** processing logic here **
    #           end
    def pipeline
      @input ||= DataCollector::Pipeline.new
    end
    module_function :pipeline
    # Read input from an URI
    # example:  input.from_uri("http://www.libis.be")
    #           input.from_uri("file://hello.txt")
    def input
      @input ||= DataCollector::Input.new
    end
    module_function :input

    # Output is an object you can store data that needs to be written to an output stream
    # output[:name] = 'John'
    # output[:last_name] = 'Doe'
    #
    # Write output to a file, string use an ERB file as a template
    # example:
    # test.erb
    #   <names>
    #     <combined><%= data[:name] %> <%= data[:last_name] %></combined>
    #     <%= print data, :name, :first_name %>
    #     <%= print data, :last_name %>
    #   </names>
    #
    # will produce
    #   <names>
    #     <combined>John Doe</combined>
    #     <first_name>John</first_name>
    #     <last_name>Doe</last_name>
    #   </names>
    #
    # Into a variable
    # result = output.to_s("test.erb")
    # Into a file stored in records dir
    # output.to_file("test.erb")
    # Into a tar file stored in data
    # output.to_file("test.erb", "my_data.tar.gz")
    # Into a temp directory
    # output.to_tmp_file("test.erb","directory")
    def output
      @output ||= Output.new
    end
    module_function :output

    #You can apply rules to input
    # A rule is made up of a Hash the key is the map key field its value is a Hash with a JSONPath filter and
    # options to apply a convert method on the filtered results.
    #
    # available convert methods are: time, map, each, call, suffix
    #  - time: Parses a given time/date string into a Time object
    #  - map: applies a mapping to a filter
    #  - suffix: adds a suffix to a result
    #  - call: executes a lambda on the filter
    #  - each: runs a lambda on each row of a filter
    #
    # example:
    # my_rules = {
    #   'identifier' => {"filter" => '$..id'},
    #   'language' => {'filter' => '$..lang',
    #                  'options' => {'convert' => 'map',
    #                                'map' => {'nl' => 'dut', 'fr' => 'fre', 'de' => 'ger', 'en' => 'eng'}
    #                               }
    #                 },
    #   'subject' => {'filter' => '$..keywords',
    #                 options' => {'convert' => 'each',
    #                              'lambda' => lambda {|d| d.split(',')}
    #                             }
    #                },
    #   'creationdate' => {'filter' => '$..published_date', 'convert' => 'time'}
    # }
    # rules.run(my_rules, input, output)
    def rules
      #DataCollector::Core.log('RULES depricated using RULESNG')
      #rules_ng
      @rules ||= Rules.new
    end
    module_function :rules

    # New rules runner
    def rules_ng
      @rules_ng ||= RulesNg.new
    end
    module_function :rules_ng

    # evaluator http://jsonpath.com/
    # uitleg http://goessner.net/articles/JsonPath/index.html
    def filter(data, filter_path)
      filtered = []
      if filter_path.is_a?(Array) && data.is_a?(Array)
        filtered = data.map {|m| m.select {|k, v| filter_path.include?(k.to_sym)}}
      elsif filter_path.is_a?(String)
        filtered = JsonPath.on(data, filter_path)
      end

      filtered = [filtered] unless filtered.is_a?(Array)
      filtered = filtered.first if filtered.length == 1 && filtered.first.is_a?(Array)

      filtered
    rescue StandardError => e
      @logger ||= self.logger
      @logger.error("#{filter_path} failed: #{e.message}")
      []
    end
    module_function :filter

    def config
      @config ||= ConfigFile
    end
    module_function :config

    def log(message)
      @logger ||= self.logger
      @logger.info(message)
    end
    module_function :log

    def error(message)
      @logger ||= self.logger
      @logger.error(message)
    end
    module_function :error

    def logger(*destinations)
      @logger ||= begin
                    destinations = STDOUT if destinations.nil? || destinations.empty?
                    Logger.new(ProxyLogger.new(destinations))
                  rescue StandardError => e
                    puts "Unable to instantiate ProxyLogger: #{e.message}"
                    Logger.new(STDOUT)
                  end
    end
    module_function :logger

  end

end
