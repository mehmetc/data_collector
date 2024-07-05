# encoding: UTF-8
require 'http'
require 'open-uri'
require 'nokogiri'
require_relative 'ext/nokogiri'
require 'linkeddata'
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
require_relative 'input/rpc'
require 'base64'

# require_relative 'ext/xml_utility_node'
module DataCollector
  class Input
    attr_reader :raw

    def initialize
      @logger = Logger.new(STDOUT)
    end

    def from_uri(source, options = {}, &block)
      block_consumed = false
      data = nil
      if source.is_a?(StringIO)
        data = from_stringio(source, options)
      else
        source = CGI.unescapeHTML(source)
        @logger.info("Reading #{source}")
        raise DataCollector::Error, 'from_uri expects a scheme like file:// of https://' unless source =~ /:\/\//

        scheme, path = source.split('://')
        source = "#{scheme}://#{URI.encode_www_form_component(path)}"
        uri = URI(source)
        begin
          case uri.scheme
          when 'http'
            data = from_http(uri, options)
          when 'https'
            data = from_https(uri, options)
          when 'file'
            absolute_path = File.absolute_path("#{URI.decode_www_form_component("#{uri.host}#{uri.path}")}")
            if File.directory?(absolute_path)
              return from_dir(uri, options)
            else
              if block_given?
                data = from_file(uri, options, &block)
                block_consumed = true if data.is_a?(TrueClass)
              else
                data = from_file(uri, options)
              end
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

        end
      end
      data = data.nil? ? 'no data found' : data

      if block_given? && !block_consumed
        yield data
      else
        data
      end
    rescue DataCollector::InputError => e
      @logger.error(e.message)
      raise e
    rescue DataCollector::Error => e
      @logger.error(e.message)
      nil
    rescue StandardError => e
      @logger.error(e.message)
      puts e.backtrace.join("\n")
      nil
    end

    private

    def from_http(uri, options = {})
      from_https(uri, options)
    end

    def from_https(uri, options = {})
      uri = URI.decode_www_form_component("#{uri.to_s}")
      data = nil
      if options.with_indifferent_access.include?(:logging) && options.with_indifferent_access[:logging]
        HTTP.default_options = HTTP::Options.new(features: { logging: { logger: @logger } })
      end

      http = HTTP

      # http.use(logging: {logger: @logger})

      if options.key?(:user) && options.key?(:password)
        @logger.debug "Set Basic_auth"
        user = options[:user]
        password = options[:password]
        http = HTTP.basic_auth(user: user, pass: password)
      elsif options.key?(:bearer_token)
        @logger.debug "Set authorization bearer token"
        bearer = options[:bearer_token]
        bearer = "Bearer #{bearer}" unless bearer =~ /^Bearer /i
        http = HTTP.auth(bearer)
      end

      if options.key?(:cookies)
        @logger.debug "Set cookies"
        http = http.cookies(options[:cookies])
      end

      if options.key?(:headers)
        @logger.debug "Set http headers"
        http = http.headers(options[:headers])
      end

      ctx = nil
      http_query_options = {}
      if options.key?(:verify_ssl) && uri.scheme.eql?('https')
        @logger.warn "Disabling SSL verification. "
        # shouldn't use this but we all do ...
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

        http_query_options[:ssl_context] = ctx
      end

      if options.key?(:method) && options[:method].downcase.eql?('post')
        raise DataCollector::InputError, "No body found, a POST request needs a body" unless options.key?(:body)
        http_query_options[:body] = options[:body]

        http_response = http.follow.post(escape_uri(uri), http_query_options)
      elsif options.key?(:method) && options[:method].downcase.eql?('put')
        raise DataCollector::InputError, "No body found, a PUT request needs a body" unless options.key?(:body)
        http_query_options[:body] = options[:body]

        http_response = http.follow.put(escape_uri(uri), http_query_options)
      else
        http_response = http.follow.get(escape_uri(uri), http_query_options)
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
            data = xml_to_hash(data, options)
          when 'text/csv'
            data = csv_to_hash(data, options)
          when 'application/xml'
            data = xml_to_hash(data, options)
          when 'text/xml'
            data = xml_to_hash(data, options)
          when 'text/html'
            data = html_to_hash(data, options)
          when 'text/turtle'
            graph = RDF::Graph.new do |graph|
              RDF::Turtle::Reader.new(data) { |reader| graph << reader }
            end
            data = JSON.parse(graph.dump(:jsonld, validate: false, standard_prefixes: true))
          when /^image/
            options['file_type'] = file_type
            data = image_to_data(data, options)
          else
            data = xml_to_hash(data, options)
          end
        end

        raise '206 Partial Content' if http_response.code == 206

      when 401
        raise DataCollector::InputError, 'Unauthorized'
      when 403
        raise DataCollector::InputError, 'Forbidden'
      when 404
        raise DataCollector::InputError, 'Not found'
      else
        raise DataCollector::InputError, "Unable to process received status code = #{http_response.code} error= #{http_response.body.to_s}"
      end

      #[data, http_response.code]
      data
    end

    def from_stringio(sio, options = {}, &block)
      raise DataCollector::InputError, "No IO input" unless sio.is_a?(StringIO)
      raise DataCollector::InputError, "content_type option not supplied" unless options.key?(:content_type)

      preferred_extension = MIME::Types[options[:content_type]].first.extensions.first || 'txt'

      file = Tempfile.new(["dc_", ".#{preferred_extension}"])
      begin
        sio.rewind
        file.write(sio.read)
        file.close
        from_file(URI("file://#{file.path}"))
      ensure
        file.unlink
      end
    end

    def from_file(uri, options = {}, &block)
      data = nil
      uri = normalize_uri(uri)
      absolute_path = File.absolute_path(uri)
      file_type = MIME::Types.type_for(uri).first.to_s
      options['file_type'] = file_type
      raise DataCollector::Error, "#{uri.to_s} not found" unless File.exist?("#{absolute_path}")
      unless options.has_key?('raw') && options['raw'] == true
        @raw = data = File.read("#{absolute_path}")
        case File.extname(absolute_path)
        when '.jsonld'
          data = JSON.parse(data)
        when '.json'
          data = JSON.parse(data)
        when '.xml'
          data = xml_to_hash(data, options)
        when '.html'
          data = html_to_hash(data, options)
        when '.gz'
          tar_data = []
          Minitar.open(Zlib::GzipReader.new(File.open("#{absolute_path}", 'rb'))) do |i|
            i.each do |entry|
              next unless entry.typeflag.eql?('0')
              if block_given?
                data = xml_to_hash(entry.read, options)
                yield data

                data = true
              else
                tar_data << entry.read

                if tar_data.length == 1
                  data = xml_to_hash(tar_data.first, options)
                else
                  data = []
                  tar_data.each do |d|
                    data << xml_to_hash(d, options)
                  end
                end
              end # block
            end # entry
          end # tar
        when '.csv'
          data = csv_to_hash(data, options)
        when '.jpg', '.png', '.gif'
          data = image_to_data(data, options)
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
      DataCollector::Input::Rpc.new(uri, options)
    end

    def image_to_data(data, options = {})
      file_type = options['file_type']
      "data:#{file_type};base64,#{Base64.encode64(data)}"
    end

    def xml_to_hash(data, options = {})
      # gsub('&lt;\/', '&lt; /') outherwise wrong XML-parsing (see records lirias1729192 )
      return unless data.is_a?(String)
      data.force_encoding('UTF-8')
      data = data.encode("UTF-8", invalid: :replace, replace: "")
      data = data.gsub /&lt;/, '&lt; /'

      xml_typecast = options.with_indifferent_access.key?('xml_typecast') ? options.with_indifferent_access['xml_typecast'] : true
      nori = Nori.new(parser: :nokogiri, advanced_typecasting: xml_typecast, strip_namespaces: true, convert_tags_to: lambda { |tag| tag.gsub(/^@/, '_') })
      nori.parse(data)
    end

    def html_to_hash(data, options = {})
      return unless data.is_a?(String)
      html_data = Nokogiri::HTML(data)
      html_data.to_hash
    end

    def csv_to_hash(data, options = {})
      csv_option_keys = options.keys & CSV::DEFAULT_OPTIONS.keys
      all_cvs_options = { headers: true, header_converters: [:downcase, :symbol] }

      csv_option_keys.each do |k|
        all_cvs_options[k] = options[k]
      end

      csv = CSV.parse(data, **all_cvs_options)

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
                    @logger.debug "No Header content-type available"
                    MIME::Types.of(filename_from(headers)).first.content_type
                  end

      return file_type
    end

    def normalize_uri(uri)
      "#{URI.decode_www_form_component(uri.host)}#{URI.decode_www_form_component(uri.path)}"
    end
  end
end
