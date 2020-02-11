require "test_helper"

include DataCollector::Core
class DataCollectorTest < Minitest::Test

  def test_should_do_text_rule
    rule = { 'hello' => { 'text' => 'world' } }

    rules.run(rule, {}, output)

    assert_equal( 'world', output[:hello])
  end

  def test_from_uri
    data = input.from_uri('file://./test/fixtures/test.csv')
    data.map{ |m| m[:sequence] *=2; m }

    output[:record] = data
    assert_equal('apple,banana,peach', output[:record].map{|m| m[:data]}.join(','))
  end
end
