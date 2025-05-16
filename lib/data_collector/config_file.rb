#encoding: UTF-8

require 'yaml'

module DataCollector
  class ConfigFile
    @config = {}
    @config_file_path = ''
    @config_file_name = 'config.yml'
    @mtime = nil

    def self.version
      '0.0.4'
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
      File.open("#{path}/#{@config_file_name}", 'w') do |f|
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
      @config_file_name = 'config.yml' if @config_file_name.nil?
      discover_config_file_path
      raise Errno::ENOENT, "#{@config_file_path}/#{@config_file_name} Not Found. Set path to #{@config_file_name}" unless File.exist?("#{@config_file_path}/#{@config_file_name}")

      ftime = File.exist?("#{@config_file_path}/#{@config_file_name}") ? File.mtime("#{@config_file_path}/#{@config_file_name}") : nil
      if @config.nil? || @config.empty? || @mtime != ftime
        # config = YAML::load_file("#{@config_file_path}/#{@config_file_name}", aliases: true, permitted_classes: [Time, Symbol])
        config = interpret_yaml_with_expressions("#{@config_file_path}/#{@config_file_name}", ENV)
        @config = process(config)
      end
    end

    def self.discover_config_file_path
      if @config_file_path.nil? || @config_file_path.empty?
        if ENV.key?('CONFIG_FILE_PATH')
          @config_file_path = ENV['CONFIG_FILE_PATH']
        elsif File.exist?(@config_file_name)
          @config_file_path = '.'
        elsif File.exist?("config/#{@config_file_name}")
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

    private
    def self.interpret_yaml_with_expressions(yaml_file, variables = {})
      # Read the YAML file content
      content = File.read(yaml_file)

      # Process any :key: "${expression}" patterns
      processed_content = content.gsub(/:key:\s*"?\$\{([^}]+)\}"?/) do |match|
        expression = $1.strip

        # Evaluate the expression using the provided variables
        if variables.key?(expression)
          # Replace with the variable value
          match.gsub("${#{expression}}", variables[expression].to_s)
        elsif expression.include?('.')
          # Handle dot notation for nested variables
          parts = expression.split('.')
          value = variables
          parts.each do |part|
            value = value[part.to_sym] if value.is_a?(Hash) && value.key?(part.to_sym)
          end
          value.to_s
        else
          # Keep the original if we can't evaluate
          match
        end
      end

      # Parse the processed YAML content
      YAML.load(processed_content, aliases: true, permitted_classes: [Time, Symbol])
    end
  end
end
