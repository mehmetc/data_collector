require 'test_helper'
require 'webmock/minitest'

include WebMock::API
WebMock.enable!

class DataCollectorInputTest < Minitest::Test
  def test_input_from_uri_file
    data = DataCollector::Input.new.from_uri('file://test/fixtures/test.csv')

    assert_equal(3, data.size)
  end

  def test_input_from_uri_http
    stub_request(:get, "https://www.example.com/").with(
      headers: {
        'Connection' => 'close',
        'Host' => 'www.example.com',
        'User-Agent' => 'http.rb/5.1.1'
      }).to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
  <collection>
      <record>apple</record>
      <record>banana</record>
      <record>peach</record>
  </collection>", headers: { "content-type" => 'application/atom+xml;charset=UTF-8' })

    url = 'https://www.example.com'
    data = input.from_uri(url, {})
    assert_equal({ "collection" => { "record" => ["apple", "banana", "peach"] } }, data)
  end

  def test_input_from_uri_tcp

  end

  def test_input_from_uri_dir
    listener = input.from_uri('file://test/fixtures/in')
    counter = 0

    listener.on_message do |input, output, file|
      log(file)
      data = JSON.parse(File.read(file))
      assert_equal('test.json', File.basename(file))
      assert_equal('world', data['hello'])
      listener.pause
    end

    begin
      listener.run(true) do #block until paused
        FileUtils.touch('test/fixtures/in/test.json')
        sleep 2
      end
    ensure
      listener.stop if listener.running?
    end

    assert_equal(false, listener.running?)
  end

  def test_input_from_uri_message

    consumer = input.from_uri('amqp://user:password@localhost?channel=resolv&queue=test')
    consumer.on_message do |input, output, message| #subscribe
      puts message
      assert_equal(message.body, 'abc')
    end

    consumer.run

    consumer.send('test','abc')

    sleep 1

    consumer.stop
  end

  def test_input_from_rpc_message
    producer = output.to_uri('rpc+amqp://user:password@localhost/resolver/admin')
    consumer = input.from_uri('rpc+amqp://user:password@localhost/resolver/admin')

    pp consumer
  end
end