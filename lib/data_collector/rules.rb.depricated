require 'logger'

module DataCollector
  class Rules
    def initialize()
      @logger = Logger.new(STDOUT)
    end

    def run(rule_map, from_record, to_record, options = {})
      rule_map.each do |map_to_key, rule|
        if rule.is_a?(Array)
          rule.each do |sub_rule|
            apply_rule(map_to_key, sub_rule, from_record, to_record, options)
          end
        else
          apply_rule(map_to_key, rule, from_record, to_record, options)
        end
      end

      to_record.each do |element|
        element = element.delete_if do |k, v|
          v != false && (v.nil?)
        end
      end
    end

    private

    def apply_rule(map_to_key, rule, from_record, to_record, options = {})
      if rule.has_key?('text')
        suffix = (rule && rule.key?('options') && rule['options'].key?('suffix')) ? rule['options']['suffix'] : ''
        to_record << { map_to_key.to_sym => add_suffix(rule['text'], suffix) }
      elsif rule.has_key?('options') && rule['options'].has_key?('convert') && rule['options']['convert'].eql?('each')
        result = get_value_for(map_to_key, rule['filter'], from_record, rule['options'], options)

        if result.is_a?(Array)
          result.each do |m|
            to_record << {map_to_key.to_sym => m}
          end
        else
          to_record << {map_to_key.to_sym => result}
        end
      else
        result = get_value_for(map_to_key, rule['filter'], from_record, rule['options'], options)
        return if result && result.empty?

        to_record << {map_to_key.to_sym => result}
      end
    end

    def get_value_for(tag_key, filter_path, record, rule_options = {}, options = {})
      data = nil
      if record
        if filter_path.is_a?(Array) && !record.is_a?(Array)
          record = [record]
        end

        data = Core::filter(record, filter_path)

        if data && rule_options
          if rule_options.key?('convert')
            case rule_options['convert']
            when 'time'
              result = []
              data = [data] unless data.is_a?(Array)
              data.each do |d|
                result << Time.parse(d)
              end
              data = result
            when 'map'
              if data.is_a?(Array)
                data = data.map do |r|
                  rule_options['map'][r] if rule_options['map'].key?(r)
                end

                data.compact!
                data.flatten! if rule_options.key?('flatten') && rule_options['flatten']
              else
                return rule_options['map'][data] if rule_options['map'].key?(data)
              end
            when 'each'
              data = [data] unless data.is_a?(Array)
              if options.empty?
                data = data.map { |d| rule_options['lambda'].call(d) }
              else
                data = data.map { |d| rule_options['lambda'].call(d, options) }
              end
              data.flatten! if rule_options.key?('flatten') && rule_options['flatten']
            when 'call'
              if options.empty?
                data = rule_options['lambda'].call(data)
              else
                data = rule_options['lambda'].call(data, options)
              end
              return data
            end
          end

          if rule_options.key?('suffix')
            data = add_suffix(data, rule_options['suffix'])
          end

        end

      end

      return data
    end

    def add_suffix(data, suffix)
      case data.class.name
      when 'Array'
        result = []
        data.each do |d|
          result <<  add_suffix(d, suffix)
        end
        data = result
      when 'Hash'
        data.each do |k, v|
          data[k] = add_suffix(v, suffix)
        end
      else
        data = data.to_s
        data += suffix
      end
      data
    end

  end
end