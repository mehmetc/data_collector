require 'logger'

module DataCollector
  class RulesNg
    def initialize(logger = Logger.new(STDOUT))
      @logger = logger
    end

    def run(rules, input_data, output_data, options = {})
      rules.each do |tag, rule|
        apply_rule(tag, rule, input_data, output_data, options)
      end

      output_data
    end

    private

    def apply_rule(tag, rule, input_data, output_data, options = {})
      rule_filter = rule
      rule_payload = ''

      case rule
      when Array
        odata = {}
        rule.each do |sub_rule|
          d = apply_rule(tag, sub_rule, input_data, output_data, options)
          next if d.nil?
          odata.merge!(d) { |k, v, n|
            [v, n].flatten
          }
        end
        odata.each do |k, v|
          output_data.data[k] = v
        end
        return output_data
      when String
        rule_filter = rule
        rule_payload = ''
      else
        rule_filter = rule.keys.first
        rule_payload = rule.values.first
      end

      case rule_filter
      when 'text'
        if rule_payload.is_a?(String)
          data = rule_payload
        else
          data = rule_payload.select { |s| s.is_a?(String) }
          rule_payload = rule_payload.reject { |s| s.is_a?(String) }
          rule_payload = '@' if rule_payload.empty?
        end
      when /json_path:/
        data = json_path_filter(rule_filter.gsub(/^json_path:/), input_data)
      else
        data = json_path_filter(rule_filter, input_data)
      end

      data = apply_filtered_data_on_payload(data, rule_payload, options)

      output_data << { tag.to_sym => data } unless data.nil? || (data.is_a?(Array) && data.empty?)
    rescue StandardError => e
      # puts "error running rule '#{tag}'\n\t#{e.message}"
      # puts e.backtrace.join("\n")
      raise DataCollector::Error, "error running rule '#{tag}'\n\t#{e.message}"
    end

    def apply_filtered_data_on_payload(input_data, payload, options = {})
      return nil if input_data.nil?

      normalized_options = options.select { |k, v| k !~ /^_/ }.with_indifferent_access
      output_data = nil
      case payload.class.name
      when 'Proc'
        data = input_data.is_a?(Array) ? input_data : [input_data]
        output_data = if normalized_options.empty? && payload.parameters.size == 1
                        # data.map { |d| payload.curry.call(d).call(d) }
                        data.map { |d|
                          loop do
                            payload_result = payload.curry.call(d)
                            break payload_result unless payload_result.is_a?(Proc)
                          end
                        }
                      else
                        data.map { |d|
                          loop do
                            payload_result = payload.curry.call(d, normalized_options)
                            break payload_result unless payload_result.is_a?(Proc)
                          end
                        }
                      end
      when 'Hash'
        input_data = [input_data] unless input_data.is_a?(Array)
        if input_data.is_a?(Array)
          output_data = input_data.map do |m|
            if payload.key?('suffix')
              if (m.is_a?(Hash))
                m.transform_values { |v| v.is_a?(String) ? "#{v}#{payload['suffix']}" : v }
              elsif m.is_a?(Array)
                m.map { |n| n.is_a?(String) ? "#{n}#{payload['suffix']}" : n }
              elsif m.methods.include?(:to_s)
                "#{m}#{payload['suffix']}"
              else
                m
              end
            else
              payload[m]
            end
          end
        end
      when 'Array'
        output_data = input_data
        payload.each do |p|
          output_data = apply_filtered_data_on_payload(output_data, p, normalized_options)
        end
      else
        output_data = [input_data]
      end

      output_data.compact! if output_data.is_a?(Array)
      output_data.flatten! if output_data.is_a?(Array)
      if options.with_indifferent_access.key?('_no_array_with_one_literal') &&
        options.with_indifferent_access['_no_array_with_one_literal'] &&
        output_data.is_a?(Array) &&
        output_data.size == 1 &&
        not((output_data.first.is_a?(Array) || output_data.first.is_a?(Hash)))
        output_data = output_data.first
        # elsif output_data.is_a?(Array) &&
        #     output_data.size == 1 &&
        #     (output_data.first.is_a?(Array) || output_data.first.is_a?(Hash))
        #   output_data = output_data.first
      end

      if options.with_indifferent_access.key?('_no_array_with_one_element') &&
        options.with_indifferent_access['_no_array_with_one_element'] &&
        output_data.is_a?(Array) && output_data.size == 1
        output_data = output_data.first
      end

      output_data
    rescue StandardError => e
      # puts "error applying filtered data on payload'#{payload.to_json}'\n\t#{e.message}"
      # puts e.backtrace.join("\n")
      raise DataCollector::Error, "error applying filtered data on payload'#{payload.to_json}'\n\t#{e.message}"
    end

    def json_path_filter(filter, input_data)
      data = nil
      return data if input_data.nil? || input_data.empty?
      return input_data if input_data.is_a?(String)

      Core.filter(input_data, filter)
    rescue StandardError => e
      puts "error running filter '#{filter}'\n\t#{e.message}"
      puts e.backtrace.join("\n")
      raise DataCollector::Error, "error running filter '#{filter}'\n\t#{e.message}"
    end
  end
end
