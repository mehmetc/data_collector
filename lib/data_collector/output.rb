#encoding: UTF-8
require 'nokogiri'
require 'erb'
require 'date'
require 'minitar'
require 'zlib'
require 'cgi'
require 'active_support/core_ext/hash'
require 'fileutils'

module DataCollector
  class Output
    include Enumerable
    attr_reader :data, :tar_file

    def initialize(data = {})
      @data = data
      @logger = Logger.new(STDOUT)
    end

    def each
      @data.each do |d|
        yield d
      end
    end

    def [](k, v = nil)
      data[k]
    end

    def []=(k, v = nil)
      unless v.nil?
        if data.has_key?(k)
          if data[k].is_a?(Array) then
            data[k] << v
          else
            t = data[k]
            data[k] = Array.new([t, v])
          end
        else
          data[k] = v
        end
      end

      data
    end

    def <<(input_data)
      if input_data.is_a?(Hash)
        input_data.each do |k, v|
          self[k] = input_data[k]
        end
      elsif input_data.is_a?(Array)
        data["datap"] = [] unless @data.has_key?("datap")
        d = @data["datap"].flatten.compact
        d += input_data
        @data["datap"] = d.compact.flatten
      end
    end

    def raw
      @data
    end

    def clear
      @data = {}
      #GC.start(full_mark: true, immediate_sweep: true)
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

      result = ERB.new(File.read(erb_file), 0, '>').result(binding)

      result
    rescue Exception => e
      raise "unable to transform to text: #{e.message}"
      ""
    end

    def to_tmp_file(erb_file, records_dir)
      id = data[:id].first rescue 'unknown'
      result = to_s(erb_file)
      xml_result = Nokogiri::XML(result, nil, 'UTF-8') do |config|
        config.noblanks
      end

      unless File.directory?(records_dir)
        FileUtils.mkdir_p(records_dir)
      end

      file_name = "#{records_dir}/#{id}_#{rand(1000)}.xml"

      File.open(file_name, 'wb:UTF-8') do |f|
        f.puts xml_result.to_xml
      end
      return file_name
    end

    def to_file(erb_file, tar_file_name = nil)
      id = data[:id].first rescue 'unknown'
      result = to_s(erb_file)

      xml_result = Nokogiri::XML(result, nil, 'UTF-8') do |config|
        config.noblanks
      end

      if tar_file_name.nil?
        file_name = "records/#{id}_#{rand(1000)}.xml"
        File.open(file_name, 'wb:UTF-8') do |f|
          f.puts xml_result.to_xml
        end

        return file_name
      else

        Minitar::Output.open(Zlib::GzipWriter.new(File.open("records/#{tar_file_name}", 'wb:UTF-8'))) do |f|
          xml_data = xml_result.to_xml
          f.tar.add_file_simple("#{id}_#{rand(1000)}.xml", data: xml_data, size: xml_data.size, mtime: Time.now.to_i)
        end

        return tar_file_name
      end

    rescue Exception => e
      raise "unable to save to file: #{e.message}"
    end


    def to_jsonfile (jsondata, jsonfile)
      file_name = "records/#{jsonfile}_#{Time.now.to_i}_#{rand(1000)}.json"
      File.open(file_name, 'wb') do |f|
        f.puts jsondata.to_json
      end
    rescue Exception => e
      raise "unable to save to jsonfile: #{e.message}"
    end

    def flatten()
      out = Hash.new
      @data.each do |m|
        out[m[0]] = m[1]
      end
      out
    end


    private

    def tar_file(tar_file_name)
      @tar_file ||= Minitar::Output.open(File.open("records/#{tar_file_name}", "a+b"))
    end
  end
end