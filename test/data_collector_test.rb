require "test_helper"

class DataCollectorTest < Minitest::Test

  def test_should_do_text_rule
    rule = { 'hello' => { 'text' => 'world' } }

    rules.run(rule, {}, output)

    assert_equal( 'world', output[:hello])
  end

  def test_time
    data = {'published_date' => '2020-01-02'}
    rule = {"pubdate" => {"filter" => '$..published_date', 'options' => {'convert' => 'time'}}}

    rules.run(rule, data, output)
    assert_instance_of(Time, output[:pubdate].first)
    assert_equal(data['published_date'], output[:pubdate].first.strftime('%Y-%m-%d'))
  end

  def test_from_uri
    data = input.from_uri('file://./test/fixtures/test.csv')
    data.map{ |m| m[:sequence] *=2; m }

    output[:record] = data
    assert_equal('apple,banana,peach', output[:record].map{|m| m[:data]}.join(','))
  end

  def test_map
    rule = {"language" => {'filter' => '@', 'options' => {'convert' => 'map', 'map' => {'nl' => 'dut', 'fr' => 'fre', 'de' => 'ger', 'en' => 'eng'}}}}
    data = ['nl', 'fr']
    output.clear
    rules.run(rule, data, output)

    assert_equal(2, output[:language].size)
    assert_equal('dut,fre', output[:language].join(','))
  end

  def test_each
    rule = {"sqrt" => {'filter' => '@', 'options' => {'convert' => 'each', 'lambda' => lambda {|d| Math.sqrt(d).to_i} }} }
    data = [9,16,25]

    output.clear
    rules.run(rule,data, output)
    assert_equal('3,4,5', output[:sqrt].join(','))
  end

  def test_suffix_text
    rule = { 'hello' => { 'text' => 'world', 'options'=> {'suffix' => '-foo'} } }

    rules.run(rule, {}, output)
    assert_equal( 'world-foo', output[:hello])
  end

  def test_suffix_array
    rule = {"sqrt" => {'filter' => '@', 'options' => {'convert' => 'each', 'suffix' => '-integer', 'lambda' => lambda {|d| Math.sqrt(d).to_i} }} }
    data = [9,16,25]

    output.clear
    rules.run(rule,data, output)
    assert_equal("3-integer,4-integer,5-integer", output[:sqrt].join(','))
  end

  def test_suffix_hash
    rule = {"reverse" => {'filter' => '$..abc', 'options' => {'convert' => 'each', 'suffix' => '-reverse', 'lambda' => lambda {|d| d.to_s.reverse}}}}
    data = {'abc' => 123}

    output.clear
    rules.run(rule,data, output)
    assert_equal("321-reverse", output[:reverse])
  end

  def test_extra_options
    rule = {"subjects" => {'filter' => '$..subject', 'options' => {'convert' => 'each', 'suffix' => '-subject', 'lambda' => lambda {|d, options| {'doc_id' => options['id'], 'subject' => d}}}}}
    data = {'subject' => ['gravitational waves', 'einstein']}

    output.clear
    rules.run(rule,data, output, {'id' => '1'})

    assert_equal('doc_id,subject', output[:subjects].first.keys.join(','))
    assert_equal('1-subject', output[:subjects].first['doc_id'])
  end

  def test_array_filter
    rule = {'tag' => [
        {'filter' => '@', 'options' => {'convert' => 'each', 'lambda' => lambda {|d| d*2}}},
        {'filter' => '@', 'options' => {'convert' => 'each', 'lambda' => lambda {|d| d*3}}}
    ]}
    data = [1,2,3]
    output.clear

    rules.run(rule, data, output)

    assert_equal(6, output[:tag].size)
    assert_equal('2,4,6,3,6,9', output[:tag].join(','))
  end

end
