#encoding: UTF-8
require 'http'
require 'open-uri'
require 'nokogiri'
require 'json/ld'
require 'nori'
require 'uri'
require 'logger'
require 'cgi'
require 'mime/types'
require 'active_support/core_ext/hash'
require 'zlib'
require 'minitar'
require 'csv'

#require_relative 'ext/xml_utility_node'
module DataCollector
  class Input
    attr_reader :raw

    def initialize
      @logger = Logger.new(STDOUT)
    end

    def from_uri(source, options = {})
      source = CGI.unescapeHTML(source)
      @logger.info("Loading #{source}")
      uri = URI(source)
      begin
        data = nil
        case uri.scheme
        when 'http'
          data = from_http(uri, options)
        when 'https'
          data = from_https(uri, options)
        when 'file'
          data = from_file(uri, options)
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

    private

    def from_http(uri, options = {})
      from_https(uri, options)
    end

    def from_https(uri, options = {})
      data = nil
      http = HTTP

      if options.keys.include?(:user) && options.keys.include?(:password)
        user = options[:user]
        password = options[:password]
        http = HTTP.basic_auth(user: user, pass: password)
      else
        @logger.warn ("User or Password parameter not found")
      end

      http_response = http.get(escape_uri(uri))

      case http_response.code
      when 200
        @raw = data = http_response.body.to_s

        # File.open("#{rand(1000)}.xml", 'wb') do |f|
        #   f.puts data
        # end

        file_type = options.with_indifferent_access.has_key?(:content_type) ? options.with_indifferent_access[:content_type] : file_type_from(http_response.headers)

        unless options.with_indifferent_access.has_key?(:raw) && options.with_indifferent_access[:raw] == true
          case file_type
          when 'application/ld+json'
            data = JSON.parse(data)
          when 'application/json'
            data = JSON.parse(data)
          when 'application/atom+xml'
            data = xml_to_hash(data)
          when 'text/csv'
            data = csv_to_hash(data)
          when 'application/xml'
            data = xml_to_hash(data)
          when 'text/xml'
            data = xml_to_hash(data)
          else
            data = xml_to_hash(data)
          end
        end
      when 401
        raise 'Unauthorized'
      when 404
        raise 'Not found'
      else
        raise "Unable to process received status code = #{http_response.code}"
      end

      data
    end

    def from_file(uri, options = {})
      data = nil
      absolute_path = File.absolute_path("#{uri.host}#{uri.path}")
      unless options.has_key?('raw') && options['raw'] == true
        @raw = data = File.read("#{absolute_path}")
        case File.extname(absolute_path)
        when '.jsonld'
          data = JSON.parse(data)
        when '.json'
          data = JSON.parse(data)
        when '.xml'
          data = xml_to_hash(data)
        when '.gz'
          Minitar.open(Zlib::GzipReader.new(File.open("#{absolute_path}", 'rb'))) do |i|
            i.each do |entry|
              data = entry.read
            end
          end
          data = xml_to_hash(data)
        when '.csv'
          data = csv_to_hash(data)
        else
          raise "Do not know how to process #{uri.to_s}"
        end
      end

      data
    end

    def xml_to_hash(data)
      #gsub('&lt;\/', '&lt; /') outherwise wrong XML-parsing (see records lirias1729192 )
      data = data.gsub /&lt;/, '&lt; /'
      nori = Nori.new(parser: :nokogiri, strip_namespaces: true, convert_tags_to: lambda { |tag| tag.gsub(/^@/, '_') })
      nori.parse(data)
      #JSON.parse(nori.parse(data).to_json)
    end

    def csv_to_hash(data)
      csv = CSV.parse(data, headers: true, header_converters: [:downcase, :symbol])

      csv.collect do |record|
        record.to_hash
      end
    end

    def escape_uri(uri)
      #"#{uri.to_s.gsub(uri.query, '')}#{CGI.escape(CGI.unescape(uri.query))}"
      uri.to_s
    end

    def file_type_from(headers)
      file_type = 'application/octet-stream'
      file_type = if headers.include?('Content-Type')
                    headers['Content-Type'].split(';').first
                  else
                    MIME::Types.of(filename_from(headers)).first.content_type
                  end

      return file_type
    end

  end
end
