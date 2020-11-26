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
        'Accept'=>'*/*', 
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'User-Agent'=>'Ruby'
  }).to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>apple</record>
      <record>banana</record>
      <record>peach</record>
  </collection>", headers: { "content-type" => 'application/atom+xml;charset=UTF-8'  }) 

stub_request(:get, "https://www.example.com/").
  with(
    basic_auth: ['account', 'secret'],
    headers: {
        'Accept'=>'*/*', 
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'User-Agent'=>'Ruby'
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
        'Accept'=>'*/*', 
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'User-Agent'=>'Ruby'
    }).
  to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>Capsicums</record>
      <record>Chilli peppers</record>
  </collection>", headers: { "Content-type" => 'application/atom+xml;charset=UTF-8'  })