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
require_relative 'input/dir'
require_relative 'input/queue'
require_relative 'input/rpc/client'
require_relative 'input/rpc/server'

#require_relative 'ext/xml_utility_node'
module DataCollector
  class Input
    attr_reader :raw

    def initialize
      @logger = Logger.new(STDOUT)
    end

    def from_uri(source, options = {})
      source = CGI.unescapeHTML(source)
      @logger.info("Reading #{source}")
      uri = URI(source)
      begin
        data = nil
        case uri.scheme
        when 'http'
          data = from_http(uri, options)
        when 'https'
          data = from_https(uri, options)
        when 'file'
          if File.directory?("#{uri.host}/#{uri.path}")
            raise DataCollector::Error, "#{uri.host}/#{uri.path} not found" unless File.exist?("#{uri.host}/#{uri.path}")
            return from_dir(uri, options)
          else
            raise DataCollector::Error, "#{uri.host}/#{uri.path} not found" unless File.exist?("#{uri.host}/#{uri.path}")
            data = from_file(uri, options)
          end
        when /amqp/
          if uri.scheme =~ /^rpc/
            data = from_rpc(uri, options)
          else
            data = from_queue(uri, options)
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

    private

    def from_http(uri, options = {})
      from_https(uri, options)
    end

    def from_https(uri, options = {})
      data = nil
      if options.with_indifferent_access.include?(:logging) && options.with_indifferent_access[:logging]
        HTTP.default_options = HTTP::Options.new(features: { logging: { logger: @logger } })
      end

      http = HTTP

      #http.use(logging: {logger: @logger})

      if options.key?(:user) && options.key?(:password)
        @logger.debug "Set Basic_auth"
        user = options[:user]
        password = options[:password]
        http = HTTP.basic_auth(user: user, pass: password)
      elsif options.key?(:bearer_token)
        @logger.debug  "Set authorization bearer token"
        bearer = options[:bearer_token]
        bearer = "Bearer #{bearer}" unless bearer =~ /^Bearer /i
        http = HTTP.auth(bearer)
      end

      if options.key?(:verify_ssl) && uri.scheme.eql?('https')
        @logger.warn "Disabling SSL verification. "
        #shouldn't use this but we all do ...
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

        http_response = http.follow.get(escape_uri(uri), ssl_context: ctx)
      else
        http_response = http.follow.get(escape_uri(uri))
      end

      case http_response.code
      when 200..299
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

        raise '206 Partial Content' if http_response.code ==206

      when 401
        raise 'Unauthorized'
      when 403
        raise 'Forbidden'
      when 404
        raise 'Not found'
      else
        raise "Unable to process received status code = #{http_response.code}"
      end

      #[data, http_response.code]
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

    def from_dir(uri, options = {})
      DataCollector::Input::Dir.new(uri, options)
    end

    def from_queue(uri, options = {})
      DataCollector::Input::Queue.new(uri, options)
    end

    def from_rpc(uri, options = {})
      if uri.to_s =~ /client/
        DataCollector::Input::Rpc::Client.new(uri, options)
      elsif uri.to_s =~ /server/
        DataCollector::Input::Rpc::Server.new(uri, options)
      end
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
                    @logger.debug  "No Header content-type available"
                    MIME::Types.of(filename_from(headers)).first.content_type
                  end

      return file_type
    end

  end
end
