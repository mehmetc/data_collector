# DataCollector
Convenience module to Extract, Transform and Load your data.  
You have main objects that help you to 'INPUT', 'OUTPUT' and 'FILTER' data. The basic ETL components.
Support objects like CONFIG, LOG, RULES and the new RULES_NG just to make life easier.

Including the DataCollector::Core module into your application gives you access to these objects.
 
The RULES and RULES_NG objects work in a very simple concept. Rules exist of 3 components:
 - a destination tag
 - a jsonpath filter to get the data 
 - a lambda to execute on every filter hit 


#### input    
Read input from an URI. This URI can have a http, https or file scheme

**Public methods**
```ruby
  from_uri(source, options = {:raw, :content_type})
```
- source: an uri with a scheme of http, https, file
- options:
    - raw: _boolean_ do not parse
    - content_type: _string_ force a content_type if the 'Content-Type' returned by the http server is incorrect 

example:
```ruby  
    input.from_uri("http://www.libis.be")
    input.from_uri("file://hello.txt")
    input.from_uri("http://www.libis.be/record.jsonld", content_type: 'application/ld+json')
```




Inputs can be JSON, XML or CSV or XML in a TAR.GZ file

 ### output 
Output is an object you can store key/value pairs that needs to be written to an output stream.  
```ruby  
    output[:name] = 'John'
    output[:last_name] = 'Doe'
```    

Write output to a file, string use an ERB file as a template
example:
___test.erb___
```ruby
<names>
    <combined><%= data[:name] %> <%= data[:last_name] %></combined>
    <%= print data, :name, :first_name %>
    <%= print data, :last_name %>
</names>
```
will produce
```ruby
   <names>
     <combined>John Doe</combined>
     <first_name>John</first_name>
     <last_name>Doe</last_name>
   </names>
```

Into a variable
```ruby
    result = output.to_s("test.erb")
```  

Into a file stored in records dir
```ruby
    output.to_file("test.erb")
``` 

Into a tar file stored in data
```ruby
    output.to_file("test.erb", "my_data.tar.gz")
```    

Other output methods
```ruby
output.raw
output.clear
output.to_tmp_file("test.erb", "tmp_data")
output.to_jsonfile(data, "test")
output.flatten
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

#### rules (depricated)
    See newer rules_ng object
~~Allows you to define a simple lambda structure to run against a JSONPath filter~~

~~A rule is made up of a Hash the key is the map key field its value is a Hash with a JSONPath filter and options to apply a convert method on the filtered results.~~
~~Available convert methods are: time, map, each, call, suffix, text~~  
~~- time: parses a given time/date string into a Time object~~  
~~- map: applies a mapping to a filter~~  
~~- suffix: adds a suffix to a result~~  
~~- call: executes a lambda on the filter~~  
~~- each: runs a lambda on each row of a filter~~  
~~- text: passthrough method. Returns value unchanged~~  

~~example:~~
```ruby 
 my_rules = {
   'identifier' => {"filter" => '$..id'},
   'language' => {'filter' => '$..lang',
                  'options' => {'convert' => 'map',
                                'map' => {'nl' => 'dut', 'fr' => 'fre', 'de' => 'ger', 'en' => 'eng'}
                               }
                 },
   'subject' => {'filter' => '$..keywords',
                 options' => {'convert' => 'each',
                              'lambda' => lambda {|d| d.split(',')}
                             }
                },
   'creationdate' => {'filter' => '$..published_date', 'convert' => 'time'}
 }

rules.run(my_rules, record, output)
```    

#### rules_ng
!!! not compatible with RULES object

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

Here is an example on how to call last RULESET "rs_hash_with_json_filter_and_option".
 
***rules_ng.run*** can have 4 parameters. First 3 are mandatory. The last one ***options*** can hold data static to a rule set or engine directives.

List of engine directives:
  - _no_array_with_one_element: defaults to false. if the result is an array with 1 element just return the element. 


```ruby
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

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/data_collector.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
