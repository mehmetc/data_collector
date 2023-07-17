# encoding: UTF-8
require 'nokogiri'
require 'erb'
require 'date'
require 'minitar'
require 'zlib'
require 'cgi'
require 'active_support/core_ext/hash'
require 'fileutils'
require_relative './output/rpc'

module DataCollector
  class Output
    include Enumerable
    attr_reader :data

    def initialize(data = {})
      @data = HashWithIndifferentAccess.new(data)
      @logger = Logger.new(STDOUT)
    end

    def each(&block)
      if block_given?
        @data.each(&block) if @data
      else
        to_enum(:each)
      end
    end

    def [](k, v = nil)
      @data[k]
    end

    def []=(k, v = nil)
      unless v.nil?
        if @data.has_key?(k)
          if @data[k].is_a?(Array) then
            if v.is_a?(Array)
              @data[k] += v
            else
              @data[k] << v
            end
          else
            @data[k] = v
            # HELP: why am I creating an array here?
            # t = data[k]
            # data[k] = Array.new([t, v])
          end
        else
          @data[k] = v
        end
      end

      @data
    end

    def <<(input_data)
      if input_data.is_a?(Hash)
        input_data.each do |k, v|
          self[k] = input_data[k]
        end
      elsif input_data.is_a?(Array)
        @data["datap"] = [] unless @data.has_key?("datap")
        d = @data["datap"].flatten.compact
        d += input_data
        @data["datap"] = d.compact.flatten
      end
    end

    def key?(key)
      @data.key?(key)
    end

    def has_key?(key)
      @data.key?(key)
    end

    def include?(key)
      @data.key?(key)
    end

    def keys
      @data.keys
    end

    def raw
      @data
    end

    def flatten()
      out = Hash.new
      @data.each do |m|
        out[m[0]] = m[1]
      end
      out
    end

    def crush
      data = @data
      @data = deep_compact(data)
    end

    def clear
      @data = {}
      # GC.start(full_mark: true, immediate_sweep: true)
      GC.start
    end

    def to_s(erb_file = nil)
      data = @data

      return data.to_s if erb_file.nil?

      def print(data, symbol, to_symbol = nil)
        tag = to_symbol ? to_symbol.to_s : symbol.to_s

        if data.with_indifferent_access[symbol]
          if data.with_indifferent_access[symbol].is_a?(Array)
            r = []
            data.with_indifferent_access[symbol].each do |d|
              r << "<#{tag}>#{CGI.escapeHTML(d.to_s)}</#{tag}>"
            end
            r.join("\n")
          elsif data.with_indifferent_access[symbol].is_a?(Hash)
            r = []
            r << "<#{tag}>"
            data.with_indifferent_access[symbol].keys.each do |k|
              r << print(data.with_indifferent_access[symbol], k)
            end
            r << "</#{tag}>"
            r.join("\n")
          else
            "<#{tag}>#{CGI.escapeHTML(data.with_indifferent_access[symbol].to_s)}</#{tag}>"
          end
        else
          nil
        end
      rescue Exception => e
        @logger.error("unable to print data '#{symbol}'")
      end

      def no_tag_print(data, symbol)
        if data.with_indifferent_access[symbol]
          if data.with_indifferent_access[symbol].is_a?(Array)
            r = []
            data.with_indifferent_access[symbol].each do |d|
              r << "#{CGI.escapeHTML(d.to_s)}"
            end
            r.join(",\n")
          else
            "#{CGI.escapeHTML(data.with_indifferent_access[symbol].to_s)}"
          end
        else
          nil
        end
      rescue Exception => e
        @logger.error("unable to print (without tag) data '#{symbol}'")
      end

      data[:response_date] = DateTime.now.xmlschema

      ERB.new(File.read(erb_file), 0, '>').result(binding)
    rescue Exception => e
      raise "unable to transform to text: #{e.message}"
    end

    def to_tmp_file(erb_file, records_dir)
      raise '[DEPRECATED] `to_tmp_file` deprecated. Please use `to_uri("file://abc.xml", {template: "template.erb", content_type: "application/xml"})` instead'
    rescue Exception => e
      raise "unable to save to file: #{e.message}"
    end

    def to_tar_file(erb_file, tar_file_name = nil)
      raise '[DEPRECATED] `to_tar_file` deprecated. Please use `to_uri("file://abc.xml", {content_type: "application/xml", tar: true})` instead'
    rescue Exception => e
      raise "unable to save to file: #{e.message}"
    end

    def to_jsonfile (jsondata, jsonfile)
      raise '[DEPRECATED] `to_jsonfile` deprecated. Please use `to_uri("file://abc.json", {template: "template.erb", content_type: "application/json"})` instead'
    rescue Exception => e
      raise "unable to save to jsonfile: #{e.message}"
    end

    def to_uri(destination, options = {})
      destination = CGI.unescapeHTML(destination)
      @logger.info("writing #{destination}")
      uri = URI(destination)
      begin
        data = nil
        case uri.scheme
        when 'http'
          data = to_http(uri, options)
        when 'https'
          data = to_https(uri, options)
        when 'file'
          data = to_file(uri, options)
        when /amqp/
          if uri.scheme =~ /^rpc/
            data = to_rpc(uri, options)
          else
            data = to_queue(uri, options)
          end
        else
          raise "Do not know how to process #{source}"
        end

        data = data.nil? ? 'no data found' : data

        if block_given?
          yield data
        else
          data
        end
      rescue => e
        @logger.info(e.message)
        puts e.backtrace.join("\n")
        nil
      end
    end

    def to_xml(options = {})
      if options.key?(:template)
        result = to_s(options[:template])
        xml_result = Nokogiri::XML(result, nil, 'UTF-8') do |config|
          config.noblanks
        end
      else
        xml_root = options[:root] || 'data'
        xml_result = Nokogiri::XML(@data.to_xml(root: xml_root), nil, 'UTF-8') do |config|
          config.noblanks
        end
      end

      xml_result.to_s
    end

    def to_json(options = {})
      if options.key?(:template)
        result = to_s(options[:template])
      else
        result = @data
      end

      result.to_json
    end

    def to_rpc(uri, options = {})
      DataCollector::Output::Rpc.new(uri, options)
    end

    def to_queueto_rpc(uri, options = {})
      raise "to be implemented"
    end

    private

    def deep_compact( data )
      if data.is_a?(Hash)
        # puts " - Hash - #{data}"
        data.compact!
        data.each { |k, v| data[k] = deep_compact(v) }
        data.compact!
      elsif data.is_a?(Array)
        # puts " - Array - #{data}"
        data.map! { |v| deep_compact(v) }
        data.compact!
        #puts " - Array size- #{data.size}"
        data.size == 1 ? data[0] : data
      elsif data.is_a?(String)
        # puts " - String - #{data}"
        data.strip.blank? ? nil : data
      else
        data
      end
    end

    def to_http(uri, options)
      to_https(uri, options)
    end

    def to_https(uri, options)

      raise 'TODO'
    end

    def to_file(uri, options)
      file_type = options[:content_type] || 'application/octet-stream'
      file_name = options[:name] || "#{uri.host}#{uri.path}" || nil
      tar_file_name = options[:tar_name] || "#{Time.now.to_i}_#{rand(1000)}.tar.gz"
      tar = options[:tar] || options.key?(:tar_name) || false
      result = ''

      case file_type
      when 'application/json'
        result = to_json(options)
        file_name = "#{Time.now.to_i}_#{rand(1000)}.json" if file_name.nil?
      when 'application/xml'
        result = to_xml(options)
        file_name = "#{Time.now.to_i}_#{rand(1000)}.xml" if file_name.nil?
      else
        file_name = "#{Time.now.to_i}_#{rand(1000)}.txt" if file_name.nil?
        result = @data.to_json
      end

      if tar
        #tar_file = Zlib::GzipWriter.new(File.open("#{tar_file_name}", 'wb'))
        tar_file = File.open("#{tar_file_name}", 'wb')

        Minitar::Output.tar(tar_file) do |f|
          f.add_file_simple("#{file_name}", {size: result.size, mtime: Time.now.to_i, data: result})
        end
      else
        file_name_absolute_path = File.absolute_path(file_name)
        file_directory = File.dirname(file_name_absolute_path)

        unless File.directory?(file_directory)
          FileUtils.mkdir_p(file_directory)
        end

        File.open(file_name_absolute_path, 'wb:UTF-8') do |f|
          f.puts result
        end
      end

      result
    rescue StandardError => e
      raise "Unable to save data: #{e.message}"
    end

  end
end
