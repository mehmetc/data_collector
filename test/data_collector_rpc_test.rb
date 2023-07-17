require 'test_helper'

class DataCollectorRPCTest < Minitest::Test
  def test_from_rpc
    listener = input.from_uri('rpc+amqp://user:password@localhost/data_collector/test')
    producer = output.to_uri('rpc+amqp://user:password@localhost/data_collector/test')

    listener.on_message do |i, o, payload|
      payload.to_i * 2
    end

    assert_equal(false, listener.running?)
    listener.run
    assert_equal(true, listener.running?)

    result = producer.send(2)

    assert_equal('ok', result['status'])
    assert_equal(4, result['data'])
    sleep 2
  ensure
    producer.stop if producer.running?
    listener.stop if listener.running?
  end
end