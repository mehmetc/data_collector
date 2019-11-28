require 'logger'

module DataCollector
  class Rules
    def initialize()
      @logger = Logger.new(STDOUT)
    end

    def run(rule_map, from_record, to_record)
      rule_map.each do |map_to_key, rule|
        if rule.is_a?(Array)
          rule.each do |sub_rule|
            apply_rule(map_to_key, sub_rule, from_record, to_record)
          end
        else
          apply_rule(map_to_key, rule, from_record, to_record)
        end
      end

      to_record.each do |element|
        element = element.delete_if{||}
      end
    end

    private
    def apply_rule(map_to_key, rule, from_record, to_record)
      if rule.has_key?('options') && rule['options'].has_key?('convert') && rule['options']['convert'].eql?('each')
        result = get_value_for(map_to_key, rule['filter'], from_record, rule['options'])

        if result.is_a?(Array)

          result.each do |m|
            to_record << {map_to_key.to_sym => m}
          end

        else
          to_record << {map_to_key.to_sym => result}
        end
      else
        to_record << {map_to_key.to_sym => get_value_for(map_to_key, rule['filter'], from_record, rule['options'])}
      end
    end

    def get_value_for(tag_key, filter_path, record, options = {})
      data = nil
      if record
        data = Core::filter(record, filter_path)

        if data && options
          if options.key?('convert')
            case options['convert']
            when 'time'
              data = Time.parse(data).strftime('%Y-%m-%d')
            when 'map'
              if data.is_a?(Array)
                data = data.map do |r|
                  return options['map'][r] if options['map'].key?(r)
                end

                data.compact!
              else
                return options['map'][data] if options['map'].key?(data)
              end
            when 'each'
              data = [data] unless data.is_a?(Array)
              data = data.map {|d| options['lambda'].call(d)}
              #pp data
            when 'call'
              return options['lambda'].call(data)
            end
          end

          if options.key?('suffix')
            data = data.to_s
            data += options['suffix']
          end

        end

      end

      return data
    end

  end
end