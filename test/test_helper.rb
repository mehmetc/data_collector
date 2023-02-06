$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "data_collector"
include DataCollector::Core

require "minitest/autorun"
require 'webmock/test_unit'

include WebMock::API

WebMock.enable!

stub_request(:get, "https://www.example.com/").
  with(
    headers:{
      'Connection'=>'close',
      'Host'=>'www.example.com',
      'User-Agent'=>'http.rb/4.4.1'
  }).to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>apple</record>
      <record>banana</record>
      <record>peach</record>
  </collection>", headers: { "content-type" => 'application/atom+xml;charset=UTF-8'  }) 

stub_request(:get, "https://www.example.com/").
  with(
    headers: {
      'Authorization'=>'Basic YWNjb3VudDpzZWNyZXQ=',
      'Connection'=>'close',
      'Host'=>'www.example.com',
      'User-Agent'=>'http.rb/4.4.1'
    }).
  to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>Pumpkins</record>
      <record>Melons</record>
      <record>Eggplant</record>
  </collection>", headers: { "Content-type" => 'application/atom+xml;charset=UTF-8'  })


stub_request(:get, "https://www.example.com/").
  with(
    headers: {
        'Authorization'=>'Bearer ABCDEfghijKLMNOpqrsTUVWXYZ', 
        'Connection'=>'close',
        'Host'=>'www.example.com',
        'User-Agent'=>'http.rb/4.4.1'
    }).
  to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>Capsicums</record>
      <record>Chilli peppers</record>
  </collection>", headers: { "Content-type" => 'application/atom+xml;charset=UTF-8'  })  

