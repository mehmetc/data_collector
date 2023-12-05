#encoding: UTF-8

require 'yaml'

module DataCollector
  class ConfigFile
    @config = {}
    @config_file_path = ''
    @config_file_name = 'config.yml'
    @mtime = nil

    def self.version
      '0.0.3'
    end

    def self.name
      @config_file_name
    end

    def self.name=(config_file_name)
      @config_file_name = config_file_name
    end

    def self.path
      @config_file_path
    end

    def self.path=(config_file_path)
      @config_file_path = config_file_path
    end

    def self.[](key)
      init
      @config[key]
    end

    def self.[]=(key, value)
      init
      @config[key] = value
      File.open( File.join( path, name), 'w') do |f|
        f.puts @config.to_yaml
      end
    end

    def self.include?(key)
      init
      @config.include?(key)
    end

    def self.keys
      init
      @config.keys
    end

    def self.init
      discover_config_file_path
      config_file = File.join( path, name)
      raise Errno::ENOENT, "#{ config_file } Not Found. Set path to #{name}" unless File.exist?( config_file )

      ftime = File.exist?( config_file ) ? File.mtime( config_file ) : nil
      if @config.empty? || @mtime != ftime
        config = YAML::load_file( config_file )
        @config = process(config)
      end
    end

    def self.discover_config_file_path
      if @config_file_path.nil? || @config_file_path.empty?
        if ENV.key?('CONFIG_FILE_PATH')
          @config_file_path = ENV['CONFIG_FILE_PATH']
        elsif File.exist?(name)
          @config_file_path = '.'
        elsif File.exist?(  File.join( "config", name) )
          @config_file_path = 'config'
        end
      end
    end

    def self.process(config)
      new_config = {}
      config.each do |k, v|
        if config[k].is_a?(Hash)
          v = process(v)
        end
        new_config.store(k.to_sym, v)
      end

      new_config
    end

    private_class_method :new
    private_class_method :init
    private_class_method :discover_config_file_path
    private_class_method :process
  end
end
