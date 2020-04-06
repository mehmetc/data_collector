require "test_helper"

class DataCollectorNgTest < Minitest::Test
  RULE_SET = {
      'rs_only_filter' => {
          'only_filter' => "$.title"
      },
      'rs_only_text' => {
          'plain_text_tag' => {
              'text' => 'hello world'
          }
      },
      'rs_text_with_suffix' => {
          'text_tag_with_suffix' => {
              'text' => ['hello_world', {'suffix' => '-suffix'}]
          }
      },
      'rs_map_with_json_filter' => {
          'language' => {
              '@' => {'nl' => 'dut', 'fr' => 'fre', 'de' => 'ger', 'en' => 'eng'}
          }
      },
      'rs_hash_with_json_filter' => {
          'multiple_of_2' => {
              '@' => lambda { |d| d.to_i * 2 }
          }
      },
      'rs_hash_with_multiple_json_filter' => {
          'multiple_of' => [
              {'@' => lambda { |d| d.to_i * 2 }},
              {'@' => lambda { |d| d.to_i * 3 }}
          ]
      },
      'rs_hash_with_json_filter_and_suffix' => {
          'multiple_of_with_suffix' => {
              '@' => [lambda {|d| d.to_i*2}, 'suffix' => '-multiple_of_2']
          }
      },
      'rs_hash_with_json_filter_and_multiple_lambdas' => {
          'multiple_lambdas' => {
              '@' => [lambda {|d| d.to_i*2}, lambda {|d| Math.sqrt(d.to_i) }]
          }
      },
      'rs_hash_with_json_filter_and_option' => {
          'subjects' => {
              '$..subject' => [
                  lambda {|d,o|
                    {
                        doc_id: o['id'],
                        subject: d
                    }
                  }
              ]
          }
      }

  }.freeze

  def test_action_text
    output.clear
    rules_ng.run(RULE_SET['rs_only_text'], {}, output)

    assert_equal(['hello world'], output[:plain_text_tag])
  end

  def test_action_text_with_suffix
    output.clear
    rules_ng.run(RULE_SET['rs_text_with_suffix'], {}, output)

    assert_equal(['hello_world-suffix'], output[:text_tag_with_suffix])
  end

  def test_action_map_input_is_string
    output.clear
    data = 'nl'
    rules_ng.run(RULE_SET['rs_map_with_json_filter'], data, output)
    assert_equal(['dut'], output[:language])
  end


  def test_action_map_input_is_array
    output.clear
    data = ['nl', 'fr']
    rules_ng.run(RULE_SET['rs_map_with_json_filter'], data, output)

    assert_equal(2, output[:language].size)
    assert_equal('dut,fre', output[:language].join(','))
  end

  def test_action_hash_with_json_filter
    output.clear
    data = '2'
    rules_ng.run(RULE_SET['rs_hash_with_json_filter'], data, output)
    assert_equal([4], output[:multiple_of_2])
  end

  def test_action_hash_with_multiple_json_filter
    output.clear
    data = '2'
    rules_ng.run(RULE_SET['rs_hash_with_multiple_json_filter'], data, output)
    assert_equal(2, output[:multiple_of].size)
    assert_equal('4,6', output[:multiple_of].join(','))
  end

  def test_action_hash_with_json_filter_and_suffix
    output.clear
    data = '2'
    rules_ng.run(RULE_SET['rs_hash_with_json_filter_and_suffix'], data, output)
    assert_equal(['4-multiple_of_2'], output[:multiple_of_with_suffix])
  end

  def test_action_hash_with_json_filter_and_multiple_lambdas
    output.clear
    data = '2'
    rules_ng.run(RULE_SET['rs_hash_with_json_filter_and_multiple_lambdas'], data, output)
    assert_equal([2.0], output[:multiple_lambdas])
  end

  def test_action_hash_with_json_filter_and_option
    output.clear
    data = {'subject' => ['water', 'thermodynamics']}

    rules_ng.run(RULE_SET['rs_hash_with_json_filter_and_option'], data, output, {'id' => 1})
    assert_equal(1, output[:subjects].first[:doc_id])
  end

  def test_action_only_filter
    output.clear
    data = {'title' => "This is a title"}

    rules_ng.run(RULE_SET['rs_only_filter'], data, output)

    assert_equal(["This is a title"], output[:only_filter])
  end
end