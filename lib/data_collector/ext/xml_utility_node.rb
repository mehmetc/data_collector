require "date"
require "time"
require "yaml"
require "bigdecimal"

require "nori/string_with_attributes"
require "nori/string_io_file"

class Nori
  class XMLUtilityNode
    alias_method :old_to_hash, :to_hash
    def to_hash
      if @type == "file"
        f = StringIOFile.new((@children.first || '').unpack('m').first)
        f.original_filename = attributes['name'] || 'untitled'
        f.content_type = attributes['content_type'] || 'application/octet-stream'
        return { name => f }
      end

      if @text
        t = typecast_value(inner_html)
        t = advanced_typecasting(t) if t.is_a?(String) && @options[:advanced_typecasting]

        if t.is_a?(String)

          # if converter = @options[:convert_attributes_to]
          #   intermediate = attributes.map {|k, v| converter.call(k, v) }.flatten
          #   attributes = Hash[*intermediate]
          # end

          t = {"$text" => t}.merge(prefixed_attributes) unless attributes.empty?
        end

        return { name => t }
      else
        #change repeating groups into an array
        groups = @children.inject({}) { |s,e| (s[e.name] ||= []) << e; s }

        out = nil
        if @type == "array"
          out = []
          groups.each do |k, v|
            if v.size == 1
              out << v.first.to_hash.entries.first.last
            else
              out << v.map{|e| e.to_hash[k]}
            end
          end
          out = out.flatten

        else # If Hash
          out = {}
          groups.each do |k,v|
            if v.size == 1
              out.merge!(v.first)
            else
              out.merge!( k => v.map{|e| e.to_hash[k]})
            end
          end
          out.merge! prefixed_attributes unless attributes.empty?
          out = out.empty? ? @options[:empty_tag_value] : out
        end

        if @type && out.nil?
          { name => typecast_value(out) }
        else
          { name => out }
        end
      end
    end
  end
end
