# DataCollector
Convenience module to Extract, Transform and Load data in a Pipeline.
The 'INPUT', 'OUTPUT' and 'FILTER' object will help you to read, transform and output your data.
Support objects like CONFIG, LOG, ERROR, RULES help you to write manageable rules to transform and log your data.
Include the DataCollector::Core module into your application gives you access to these objects.
```ruby
include DataCollector::Core
```
Every object can be used on its own.

#### Pipeline
Allows you to create a simple pipeline of operations to process data. With a data pipeline, you can collect, process, and transform data, and then transfer it to various systems and applications.

You can set a schedule for pipelines that are triggered by new data, specifying how often the pipeline should be 
executed in the [ISO8601 duration format](https://www.digi.com/resources/documentation/digidocs//90001488-13/reference/r_iso_8601_duration_format.htm). The processing logic is then executed.   
###### methods:
 - .new(options): options can be schedule in [ISO8601 duration format](https://www.digi.com/resources/documentation/digidocs//90001488-13/reference/r_iso_8601_duration_format.htm)  and name
   - options:
     - name: pipeline name
     - schedule: [ISO8601 duration format](https://www.digi.com/resources/documentation/digidocs//90001488-13/reference/r_iso_8601_duration_format.htm)
     - cron: in cron format ex. '1 12 * * *' intervals are not supported
     - uri: a directory/file to watch
 - .run: start the pipeline. blocking if a schedule is supplied
 - .stop: stop the pipeline
 - .pause: pause the pipeline. Restart using .run
 - .running?: is pipeline running
 - .stopped?: is pipeline not running
 - .paused?: is pipeline paused
 - .name: name of the pipe
 - .run_count: number of times the pipe has ran
 - .on_message: handle to run every time a trigger event happens
###### example:
```ruby
#create a pipeline scheduled to run every 10 minutes
pipeline = Pipeline.new(schedule: 'PT10M')

pipeline.on_message do |input, output|
  data = input.from_uri("https://dummyjson.com/comments?limit=10")
  # process data
end

pipeline.run
```

```ruby
#create a pipeline scheduled to run every morning at 06:00 am
pipeline = Pipeline.new(schedule: '0 6 * * *')

pipeline.on_message do |input, output|
  data = input.from_uri("https://dummyjson.com/comments?limit=10")
  # process data
end

pipeline.run
```


```ruby
#create a pipeline to listen and process files in a directory
extract = DataCollector::Pipeline.new(name: 'extract', uri: 'file://./data/in')

extract.on_message do |input, output, filename|
  data = input.from_uri("file://#{filename}")
  # process data
end

extract.run
```

#### input
The input component is part of the processing logic. All data is converted into a Hash, Array, ... accessible using plain Ruby or JSONPath using the filter object.  
The input component can fetch data from various URIs, such as files, URLs, directories, queues, ...  
For a push input component, a listener is created with a processing logic block that is executed whenever new data is available.
A push happens when new data is created in a directory, message queue, ...

```ruby
  from_uri(source, options = {:raw, :content_type})
```
- source: an uri with a scheme of http, https, file, amqp
- options:
    - raw: _boolean_ do not parse
    - content_type: _string_ force a content_type if the 'Content-Type' returned by the http server is incorrect 

###### example:
```ruby  
# read from an http endpoint
    input.from_uri("http://www.libis.be")
    input.from_uri("file://hello.txt")
    input.from_uri("http://www.libis.be/record.jsonld", content_type: 'application/ld+json')

# read data from a RabbitMQ queue
    listener = input.from_uri('amqp://user:password@localhost?channel=hello&queue=world')
    listener.on_message do |input, output, message| 
      puts message
    end
    listener.run

# read data from a directory
    listener = input.from_uri('file://this/is/directory')
    listener.on_message do |input, output, filename|
      puts filename
    end
    listener.run
```

Inputs can be JSON, XML or CSV or XML in a TAR.GZ file   

###### listener from input.from_uri(directory|message queue)
When a listener is defined that is triggered by an event(PUSH) like a message queue or files written to a directory you have these extra methods.

- .run: start the listener. blocking if a schedule is supplied
- .stop: stop the listener
- .pause: pause the listener. Restart using .run
- .running?: is listener running
- .stopped?: is listener not running
- .paused?: is listener paused
- .on_message: handle to run every time a trigger event happens

 ### output 
Output is an object you can store key/value pairs that needs to be written to an output stream.  
```ruby  
    output[:name] = 'John'
    output[:last_name] = 'Doe'
```    

```ruby
# get all keys from the output object
    output.keys
    output.key?(:name)
    output.each do |k,v|
      puts "#{k}:#{v}"      
    end
```
```ruby
# add hash to output
    output << { age: 22 }

    puts output[:age]
# # 22
```
```ruby
# add array to output
    output << [1,2,3,4]
    puts output.keys
# # datap
    puts output['datap']
# # [1, 2, 3, 4]
```

Write output to a file, string use an ERB file as a template
example:
___test.erb___
```erbruby
<names>
    <combined><%= data[:name] %> <%= data[:last_name] %></combined>
    <%= print data, :name, :first_name %>
    <%= print data, :last_name %>
</names>
```
will produce
```html
   <names>
     <combined>John Doe</combined>
     <first_name>John</first_name>
     <last_name>Doe</last_name>
   </names>
```

Into a variable
```ruby
    result = output.to_s("test.erb")
#template is optional
    result = output.to_s
```  

Into a file
```ruby
    output.to_uri("file://data.xml", {template: "test.erb", content_type: "application/xml"})
#template is optional
    output.to_uri("file://data.json", {content_type: "application/json"})
``` 

Into a tar file stored in data
```ruby
# create a tar file with a random name
    data = output.to_uri("file://data.json", {content_type: "application/json", tar:true})
#choose
    data = output.to_uri("file://./test.json", {template: "test.erb", content_type: 'application/json', tar_name: "test.tar.gz"}) 
```    

Other output methods
```ruby
output.raw
output.clear
output.to_xml(template: 'test.erb', root: 'record') # root defaults to 'data'
output.to_json
output.flatten
output.crush
output.keys
```

Into a temp directory
```ruby
    output.to_tmp_file("test.erb","directory")
```    
   
#### filter
filter data from a hash using [JSONPath](http://goessner.net/articles/JsonPath/index.html)

```ruby
    filtered_data = filter(data, "$..metadata.record")
```

#### rules 
The RULES objects have a simple concept. Rules exist of 3 components:
- a destination tag
- a jsonpath filter to get the data
- a lambda to execute on every filter hit

TODO: work in progress see test for examples on how to use

```
RULE_SET
    RULES*
        FILTERS*
            LAMBDA*
            SUFFIX
```

##### Examples

Here you find different rule combination that are possible

``` ruby
 RULE_SETS = {
      'rs_only_filter' => {
          'only_filter' => "$.title"
      },
      'rs_only_text' => {
          'plain_text_tag' => {
              'text' => 'hello world'
          }
      },
      'rs_text_with_suffix' => {
          'text_tag_with_suffix' => {
              'text' => ['hello_world', {'suffix' => '-suffix'}]
          }
      },
      'rs_map_with_json_filter' => {
          'language' => {
              '@' => {'nl' => 'dut', 'fr' => 'fre', 'de' => 'ger', 'en' => 'eng'}
          }
      },
      'rs_hash_with_json_filter' => {
          'multiple_of_2' => {
              '@' => lambda { |d| d.to_i * 2 }
          }
      },
      'rs_hash_with_multiple_json_filter' => {
          'multiple_of' => [
              {'@' => lambda { |d| d.to_i * 2 }},
              {'@' => lambda { |d| d.to_i * 3 }}
          ]
      },
      'rs_hash_with_json_filter_and_suffix' => {
          'multiple_of_with_suffix' => {
              '@' => [lambda {|d| d.to_i*2}, 'suffix' => '-multiple_of_2']
          }
      },
      'rs_hash_with_json_filter_and_multiple_lambdas' => {
          'multiple_lambdas' => {
              '@' => [lambda {|d| d.to_i*2}, lambda {|d| Math.sqrt(d.to_i) }]
          }
      },
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
```

 
***rules.run*** can have 4 parameters. First 3 are mandatory. The last one ***options*** can hold data static to a rule set or engine directives.

##### List of engine directives:
  - _no_array_with_one_element: defaults to false. if the result is an array with 1 element just return the element. 

###### example:
```ruby
# apply RULESET "rs_hash_with_json_filter_and_option" to data
    include DataCollector::Core
    output.clear
    data = {'subject' => ['water', 'thermodynamics']}

    rules_ng.run(RULE_SETS['rs_hash_with_json_filter_and_option'], data, output, {'id' => 1})

```

Results in: 
```json
  {
   "subjects":[
                {"doc_id":1,"subject":"water"},
                {"doc_id":1,"subject":"thermodynamics"}
              ]
  }
```



#### config
config is an object that points to "config.yml" you can read and/or store data to this object.

___read___    
```ruby
    config[:active]
```    
___write___
```ruby
    config[:active] = false
```    
#### log
Log to stdout
```ruby
    log("hello world")
```
#### error
Log an error
```ruby
    error("if you have an issue take a tissue")
```
## Example
Input data ___test.csv___
```csv
sequence, data
1, apple
2, banana
3, peach
```

Output template ___test.erb___
```ruby
 <data>
 <% data[:record].each do |d| %>
    <record sequence="<%= d[:sequence] %>">
      <%= print d, :data %>
    </record>
 <% end %>
</data>
```

```ruby
require 'data_collector'
include DataCollector::Core

data = input.from_uri('file://test.csv')
data.map{ |m| m[:sequence] *=2; m }

output[:record]=data

puts output.to_s('test.erb')
```

Should give as output
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


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'data_collector'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install data_collector

## Usage

```ruby
require 'data_collector'

include DataCollector::Core
# including core gives you a pipeline, input, output, filter, config, log, error object to work with
RULES = {
        'title' => '$..vertitle'
}
#create a PULL pipeline and schedule it to run every 5 seconds
pipeline = DataCollector::Pipeline.new(schedule: 'PT5S')

pipeline.on_message do |input, output|
  data = input.from_uri('https://services3.libis.be/primo_artefact/lirias3611609')
  rules.run(RULES, data, output)
  #puts JSON.pretty_generate(input.raw)
  puts JSON.pretty_generate(output.raw)
  output.clear
  
  if pipeline.run_count > 2
    log('stopping pipeline after one run')
    pipeline.stop
  end
end
pipeline.run

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/data_collector.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
