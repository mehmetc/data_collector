# DataCollector
Convinience module to Extract, Transform and Load your data.

#### input    
Read input from an URI
example:
```ruby  
    input.from_uri("http://www.libis.be")
    input.from_uri("file://hello.txt")
```

Inputs can be JSON, XML or CSV

 ### output 
Output is an object you can store data that needs to be written to an output stream.  
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

Into a temp directory
```ruby
    output.to_tmp_file("test.erb","directory")
```    
   
#### filter
filter data from a hash using [JsonPath](http://goessner.net/articles/JsonPath/index.html)

```ruby
    filtered_data = filter(data, "$..metadata.record")
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
