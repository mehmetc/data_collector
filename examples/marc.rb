$LOAD_PATH << '../lib'
require 'data_collector'

# include module gives us an pipeline, input, output, filter, log and error object to work with
include DataCollector::Core

RULES = {
  "title" => {'$.record.datafield[?(@._tag == "245")]' => lambda do |d, o|
    subfields = d['subfield']
    subfields = [subfields] unless subfields.is_a?(Array)
    subfields.map{|m| m["$text"]}.join(' ')
  end
  },
  "author" => {'$..datafield[?(@._tag == "100")]' => lambda do |d, o|
    subfields = d['subfield']
    subfields = [subfields] unless subfields.is_a?(Array)
    subfields.map{|m| m["$text"]}.join(' ')
  end
  }
}

#read remote record enable logging
data = input.from_uri('https://gist.githubusercontent.com/kefo/796b39925e234fb6d912/raw/3df2ce329a947864ae8555f214253f956d679605/sample-marc-with-xsd.xml', {logging: true})
# apply rules to data and if result contains only 1 entry do not return an array
rules.run(RULES, data, output, {_no_array_with_one_element: true})
# print result
puts JSON.pretty_generate(output.raw)