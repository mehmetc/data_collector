# DataCollector Ruby Gem

## Overview

DataCollector is a convenience module for Extract, Transform, and Load (ETL) operations in a pipeline architecture. It provides a simple way to collect, process, transform, and transfer data to various systems and applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'data_collector'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install data_collector
```

## Getting Started

Include the DataCollector::Core module in your application to access all available objects:

```ruby
require 'data_collector'
include DataCollector::Core
```

This gives you access to the following objects: `pipeline`, `input`, `output`, `filter`, `rules`, `config`, `log`, and `error`.

## Core Components

### Pipeline

The Pipeline object allows you to create a data processing pipeline with scheduled execution.

#### Methods

- `.new(options)`: Create a new pipeline
  - Options:
    - `name`: Pipeline name
    - `schedule`: ISO8601 duration format (e.g., 'PT10M' for every 10 minutes)
    - `cron`: Cron format (e.g., '0 6 * * *' for 6:00 AM daily)
    - `uri`: Directory/file to watch
    - `xml_typecast`: Convert string values to appropriate types (true/false)
- `.run`: Start the pipeline (blocking if schedule is supplied)
- `.stop`: Stop the pipeline
- `.pause`: Pause the pipeline
- `.running?`: Check if pipeline is running
- `.stopped?`: Check if pipeline is not running
- `.paused?`: Check if pipeline is paused
- `.name`: Get pipeline name
- `.run_count`: Get number of times the pipeline has run
- `.on_message`: Handle to run every time a trigger event happens

#### Examples

Time-scheduled pipeline:
```ruby
# Run every 10 minutes
pipeline = Pipeline.new(schedule: 'PT10M')

pipeline.on_message do |input, output|
  data = input.from_uri("https://dummyjson.com/comments?limit=10")
  # Process data
end

pipeline.run
```

Cron-scheduled pipeline:
```ruby
# Run every morning at 06:00 AM
pipeline = Pipeline.new(cron: '0 6 * * *')

pipeline.on_message do |input, output|
  data = input.from_uri("https://dummyjson.com/comments?limit=10")
  # Process data
end

pipeline.run
```

File-watching pipeline:
```ruby
# Listen for and process files in a directory
extract = DataCollector::Pipeline.new(name: 'extract', uri: 'file://./data/in')

extract.on_message do |input, output, filename|
  data = input.from_uri("file://#{filename}")
  # Process data
end

extract.run
```

### Input

The input component fetches data from various URIs and converts it into Ruby objects (Hash, Array, etc.).

#### Methods

- `from_uri(source, options = {})`: Fetch data from a source
  - Parameters:
    - `source`: URI with scheme (http, https, file, amqp)
    - `options`:
      - `raw`: Boolean (do not parse)
      - `content_type`: String (force a specific content type)
      - `headers`: Request headers
      - `cookies`: Session cookies
      - `method`: HTTP verb (GET, POST)
      - `body`: HTTP post body

#### Examples

HTTP and file sources:
```ruby
# Read from an HTTP endpoint
input.from_uri("http://www.libis.be")

# Read from a file
input.from_uri("file://hello.txt")

# Force content type
input.from_uri("http://www.libis.be/record.jsonld", content_type: 'application/ld+json')

# Read RDF/Turtle data
input.from_uri("https://www.w3.org/TR/rdf12-turtle/examples/example1.ttl")

# POST request
input.from_uri(
  "https://dbpedia.org/sparql",
  body: "query=SELECT * WHERE {?sub ?pred ?obj} LIMIT 10",
  method: "POST",
  headers: {accept: "text/turtle"}
)

# Read from StringIO
input.from_uri(
  StringIO.new(File.read('myrecords.xml')),
  content_type: 'application/xml'
)
```

Message queues:
```ruby
# Read data from a RabbitMQ queue
listener = input.from_uri('amqp://user:password@localhost?channel=hello&queue=world')
listener.on_message do |input, output, message| 
  puts message
end
listener.run
```

Directory monitoring:
```ruby
# Read data from a directory
listener = input.from_uri('file://this/is/directory')
listener.on_message do |input, output, filename|
  puts filename
end
listener.run
```

CSV files with options:
```ruby
# Load a CSV with semicolon separator
data = input.from_uri('https://example.com/data.csv', col_sep: ';')
```

#### Listener Methods

When a listener is defined (for directories or message queues):

- `.run`: Start the listener (blocking)
- `.stop`: Stop the listener
- `.pause`: Pause the listener
- `.running?`: Check if listener is running
- `.stopped?`: Check if listener is not running
- `.paused?`: Check if listener is paused
- `.on_message`: Handle to run every time a trigger event happens

### Output

Output is an object for storing key/value pairs to be written to an output stream.

#### Basic Operations

```ruby
# Set values
output[:name] = 'John'
output[:last_name] = 'Doe'

# Get all keys
output.keys

# Check if key exists
output.key?(:name)

# Iterate through keys and values
output.each do |k, v|
  puts "#{k}:#{v}"
end

# Add hash to output
output << { age: 22 }
puts output[:age]  # 22

# Add array to output
output << [1, 2, 3, 4]
puts output['datap']  # [1, 2, 3, 4]

# Clear output
output.clear
```

#### Output Methods

- `to_s(template = nil)`: Convert output to string (optional ERB template)
- `to_uri(uri, options = {})`: Write output to a URI
  - Options:
    - `template`: ERB template file
    - `content_type`: MIME type
    - `tar`: Create a tar file (true/false)
    - `tar_name`: Custom name for tar file
- `to_tmp_file(template, directory)`: Write to temporary file
- `to_xml(options = {})`: Convert to XML
  - Options:
    - `template`: ERB template
    - `root`: Root element name (defaults to 'data')
- `to_json`: Convert to JSON
- `flatten`: Flatten nested structures
- `crush`: Compress output
- `raw`: Get raw output data

#### Examples

Using ERB templates:
```ruby
# Template (test.erb)
# <names>
#     <combined><%= data[:name] %> <%= data[:last_name] %></combined>
#     <%= print data, :name, :first_name %>
#     <%= print data, :last_name %>
# </names>

# Generate string from template
result = output.to_s("test.erb")

# Without template
result = output.to_s
```

Writing to files:
```ruby
# Write to file with template
output.to_uri(
  "file://data.xml",
  {template: "test.erb", content_type: "application/xml"}
)

# Write to file without template
output.to_uri("file://data.json", {content_type: "application/json"})
```

Creating tar archives:
```ruby
# Create tar with random name
data = output.to_uri(
  "file://data.json",
  {content_type: "application/json", tar: true}
)

# Create tar with specific name
data = output.to_uri(
  "file://./test.json",
  {
    template: "test.erb",
    content_type: 'application/json',
    tar_name: "test.tar.gz"
  }
)
```

### Filter

Filter data from a hash using JSONPath.

```ruby
# Extract data using JSONPath
filtered_data = filter(data, "$..metadata.record")
```

### Rules

Rules provide a systematic way to transform data using three components:
- A destination tag
- A JSONPath filter to get the data
- A lambda function to execute on every filter hit

#### Example Rule Sets

```ruby
RULE_SETS = {
  # Simple filter
  'rs_only_filter' => {
    'only_filter' => "$.title"
  },
  
  # Plain text
  'rs_only_text' => {
    'plain_text_tag' => {
      'text' => 'hello world'
    }
  },
  
  # Text with suffix
  'rs_text_with_suffix' => {
    'text_tag_with_suffix' => {
      'text' => ['hello_world', {'suffix' => '-suffix'}]
    }
  },
  
  # Map values
  'rs_map_with_json_filter' => {
    'language' => {
      '@' => {'nl' => 'dut', 'fr' => 'fre', 'de' => 'ger', 'en' => 'eng'}
    }
  },
  
  # Transform with lambda
  'rs_hash_with_json_filter' => {
    'multiple_of_2' => {
      '@' => lambda { |d| d.to_i * 2 }
    }
  },
  
  # Multiple transforms
  'rs_hash_with_multiple_json_filter' => {
    'multiple_of' => [
      {'@' => lambda { |d| d.to_i * 2 }},
      {'@' => lambda { |d| d.to_i * 3 }}
    ]
  },
  
  # Transform with suffix
  'rs_hash_with_json_filter_and_suffix' => {
    'multiple_of_with_suffix' => {
      '@' => [lambda {|d| d.to_i*2}, 'suffix' => '-multiple_of_2']
    }
  },
  
  # Multiple lambdas
  'rs_hash_with_json_filter_and_multiple_lambdas' => {
    'multiple_lambdas' => {
      '@' => [lambda {|d| d.to_i*2}, lambda {|d| Math.sqrt(d.to_i) }]
    }
  },
  
  # With options
  'rs_hash_with_json_filter_and_option' => {
    'subjects' => {
      '$..subject' => [
        lambda {|d,o|
          {
            doc_id: o['id'],
            subject: d
          }
        }
      ]
    }
  }
}
```

#### Using Rules

```ruby
# Apply rule set with options
data = {'subject' => ['water', 'thermodynamics']}
rules.run(RULE_SETS['rs_hash_with_json_filter_and_option'], data, output, {'id' => 1})

# Result:
# {
#   "subjects":[
#     {"doc_id":1,"subject":"water"},
#     {"doc_id":1,"subject":"thermodynamics"}
#   ]
# }
```

Engine directives:
- `no_array_with_one_element`: If true and result is a single-element array, return just the element (default: false)

### Config

The config object points to a configuration file (default: "config.yml").

__Example__ config.yml
```yaml
cache: "/tmp"
password: ${SECRET}
active: true
```

__Usage__
```ruby
# Set config path and filename
config.path = "/path/to/my/config"
config.name = "not_my_config.yml"

# Check config
puts config.version
puts config.include?(:key)
puts config.keys

# Read config value
config[:active]

# Write config value
config[:active] = false
```

### Logging

```ruby
# Log to stdout
log("hello world")

# Log error
error("if you have an issue take a tissue")

# Configure logger outputs
f = File.open('/tmp/data.log', 'w')
f.sync = true  # Do not buffer
logger(STDOUT, f)  # Log to both STDOUT and file
```

## Complete Example

Input data (test.csv):
```csv
sequence, data
1, apple
2, banana
3, peach
```

Output template (test.erb):
```erb
<data>
<% data[:record].each do |d| %>
   <record sequence="<%= d[:sequence] %>">
     <%= print d, :data %>
   </record>
<% end %>
</data>
```

Processing script:
```ruby
require 'data_collector'
include DataCollector::Core

# Read CSV data
data = input.from_uri('file://test.csv')

# Transform data
data.map{ |m| m[:sequence] *=2; m }

# Store in output
output[:record] = data

# Generate result using template
puts output.to_s('test.erb')
```

Output:
```xml
<data>
   <record sequence="11">
       <data> apple</data>    
   </record>
   <record sequence="22">
       <data> banana</data>    
   </record>
   <record sequence="33">
       <data> peach</data>    
   </record>
</data>
```

## Full Pipeline Example

```ruby
require 'data_collector'

include DataCollector::Core

# Define rules
RULES = {
  'title' => '$..vertitle'
}

# Create a PULL pipeline and schedule it to run every 5 seconds
pipeline = DataCollector::Pipeline.new(schedule: 'PT5S')

pipeline.on_message do |input, output|
  # Fetch data
  data = input.from_uri('https://services3.libis.be/primo_artefact/lirias3611609')
  
  # Apply rules
  rules.run(RULES, data, output)
  
  # Output results
  puts JSON.pretty_generate(output.raw)
  output.clear
  
  # Stop after 3 runs
  if pipeline.run_count > 2
    log('stopping pipeline after one run')
    pipeline.stop
  end
end

pipeline.run
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
