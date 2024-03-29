require "test_helper"
require 'webmock/minitest'

include WebMock::API

WebMock.enable!

class DataCollectorUriTest < Minitest::Test

  def test_from_https
    stub_request(:get, "https://www.example.com/").with(
      headers: {
        'Connection' => 'close',
        'Host' => 'www.example.com',
        'User-Agent' => 'http.rb/5.2.0'
      }).to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>apple</record>
      <record>banana</record>
      <record>peach</record>
  </collection>", headers: { "content-type" => 'application/atom+xml;charset=UTF-8' })

    url = 'https://www.example.com'
    options = {}
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["apple", "banana", "peach"]}},  output[:record])
  end
  #
  def test_from_https_with_basic_auth
    stub_request(:get, "https://www.example.com/").
      with(
        basic_auth: ['account', 'secret'],
        headers: {
          'Connection'=>'close',
          'Host'=>'www.example.com',
          'User-Agent' => 'http.rb/5.2.0'
        }).
      to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <collection>
          <record>Pumpkins</record>
          <record>Melons</record>
          <record>Eggplant</record>
      </collection>", headers: { "Content-type" => 'application/atom+xml;charset=UTF-8'  })


    url = 'https://www.example.com'
    options = {user: "account", password: "secret"}
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["Pumpkins", "Melons", "Eggplant"]}},  output[:record])
  end
  #
  def test_from_https_with_bearer_token
    stub_request(:get, "https://www.example.com/").
      with(
        headers: {
          'Authorization'=>'Bearer ABCDEfghijKLMNOpqrsTUVWXYZ',
          'Connection'=>'close',
          'Host'=>'www.example.com',
          'User-Agent' => 'http.rb/5.2.0'
        }).
      to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <collection>
          <record>Capsicums</record>
          <record>Chilli peppers</record>
      </collection>", headers: { "Content-type" => 'application/atom+xml;charset=UTF-8'  })

    url = 'https://www.example.com'
    options = {bearer_token: "ABCDEfghijKLMNOpqrsTUVWXYZ"}
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["Capsicums", "Chilli peppers"]}},  output[:record])
  end

  def test_from_https_with_bearer_token_headers_cookies
    stub_request(:get, "https://www.example.com/").
      with(
        headers: {
          'Authorization'=>'Bearer ABCDEfghijKLMNOpqrsTUVWXYZ',
          'Cookie'=>'auth_token=auth_secret_cookie_token',
          'Connection'=>'close',
          'Host'=>'www.example.com',
          'x-csrf-token' => 'secret_token',
          'User-Agent'=>'Mozilla_test'
        }).
      to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <collection>
          <record>Capsicums</record>
          <record>Chilli peppers</record>
      </collection>", headers: { "Content-type" => 'application/atom+xml;charset=UTF-8'  })

    url = 'https://www.example.com'
    options = {bearer_token: "ABCDEfghijKLMNOpqrsTUVWXYZ", headers: { "User-Agent" => "Mozilla_test", "x-csrf-token" => "secret_token" }, cookies: { :auth_token => "auth_secret_cookie_token"} }
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["Capsicums", "Chilli peppers"]}},  output[:record])
  end
  
  def test_from_https_with_404
    stub_request(:get, "https://www.example.com/404").with(
      headers: {
        'Connection' => 'close',
        'Host' => 'www.example.com',
        'User-Agent' => 'http.rb/5.2.0'
      }).to_return(status: 404, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <error>
      <status>404</status>
  </error>", headers: { "content-type" => 'application/atom+xml;charset=UTF-8' })

    url = 'https://www.example.com/404'
    options = {}

    assert_raises(DataCollector::InputError) do
      data = input.from_uri(url, options)
    end
  end

  def test_from_uri
    data = input.from_uri('file://./test/fixtures/test.csv')
    data.map{ |m| m[:sequence] *=2; m }

    output[:record] = data
    assert_equal('apple,banana,peach', output[:record].map{|m| m[:data]}.join(','))
  end
end
