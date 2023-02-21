require "test_helper"

class DataCollectorUriTest < Minitest::Test

  def test_from_https
    url = 'https://www.example.com'
    options = {}
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["apple", "banana", "peach"]}},  output[:record])
  end

  def test_from_https_with_basic_auth
    url = 'https://www.example.com'
    options = {user: "account", password: "secret"}
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["Pumpkins", "Melons", "Eggplant"]}},  output[:record])
  end

  def test_from_https_with_bearer_token
    url = 'https://www.example.com'
    options = {bearer_token: "ABCDEfghijKLMNOpqrsTUVWXYZ"}
    data = input.from_uri(url, options)

    output[:record] = data
    assert_equal({"collection"=>{"record"=>["Capsicums", "Chilli peppers"]}},  output[:record])
  end

  def test_from_uri
    data = input.from_uri('file://./test/fixtures/test.csv')
    data.map{ |m| m[:sequence] *=2; m }

    output[:record] = data
    assert_equal('apple,banana,peach', output[:record].map{|m| m[:data]}.join(','))
  end
end