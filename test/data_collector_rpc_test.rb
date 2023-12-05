require 'test_helper'

class DataCollectorRPCTest < Minitest::Test
  def test_from_rpc
    listener = DataCollector::Input.new.from_uri('rpc+amqp://user:password@localhost/data_collector/test')
    producer = DataCollector::Output.new.to_uri('rpc+amqp://user:password@localhost/data_collector/test')

    listener.on_message do |i, o, payload|
      puts "getting message"
      payload.to_i * 2
    end

    assert_equal(false, listener.running?)
    listener.run
    assert_equal(true, listener.running?)

    result = producer.send(2)

    assert_equal('ok', result['status'])
    assert_equal(4, result['data'])
    sleep 2

    result = producer.send(4)
    assert_equal('ok', result['status'])
    assert_equal(8, result['data'])
    sleep 2
  ensure
    puts "listener stop"
    listener.stop if listener.running?

    puts "producer stop"
    producer.stop if producer.running?
  end
end