require 'test_helper'
require 'webmock/minitest'

include WebMock::API
WebMock.enable!

class DataCollectorInputTest < Minitest::Test
  def test_output_add_hash
    output = DataCollector::Output.new
    output['a'] = 1

    assert_equal(true, output.key?('a'))

    output << {'b' => 2}
    assert_equal(true, output.key?('b'))
    output.each do |k,v|
      puts "#{k}:#{v}"
    end
    a = output.select{|k,v| k.eql?('a') }
    pp a
  end

  def test_output_add_array
    output = DataCollector::Output.new
    output << [1,2,3,4]

    assert_equal(true, output.key?('datap'))
    assert_equal(4, output['datap'].length)

    assert_includes(output.keys, 'datap')
    pp output[:datap]
  end

  def test_output_to_file_as_json
    File.unlink('./test.json') if File.exist?('./test.json')
    output = DataCollector::Output.new

    output['a']=1
    output['b']=2
    output['c']=3

    data_out = output.to_uri("file://./test.json", {content_type: 'application/json'})
    assert_equal(output.raw.to_json, data_out)
    input = DataCollector::Input.new
    data_in = input.from_uri("file://./test.json")

    assert_equal(data_out, data_in.to_json)
    File.unlink('./test.json') if File.exist?('./test.json')
  end

  def test_output_to_file_as_xml
    File.unlink('./test.xml') if File.exist?('./test.xml')
    output = DataCollector::Output.new

    output['a']=1
    output['b']=2
    output['c']=3

    data_out = output.to_uri("file://./test.xml", {content_type: 'application/xml'})
    assert_equal(output.to_xml, data_out)
    input = DataCollector::Input.new
    data_in = input.from_uri("file://./test.xml", {content_type: 'application/xml'})

    assert_equal(data_out, data_in['data'].to_xml(root: 'data'))
    File.unlink('./test.xml') if File.exist?('./test.xml')
  end

  def test_output_to_file_tar_file
    File.unlink('./test.tar') if File.exist?('./test.tar')
    File.unlink('./test.json') if File.exist?('./test.json')
    output = DataCollector::Output.new

    output['a']=1
    output['b']=2
    output['c']=3

    data_out = output.to_uri("file://./test.json", {content_type: 'application/json', tar_name: "test.tar"})
    assert_equal(true, File.exist?('test.tar'))
    file = Minitar::Input.each_entry(File.open('test.tar', 'r')) do |entry|
      assert_equal('./test.json', entry.name)
    end

    File.unlink('./test.tar') if File.exist?('./test.tar')
    File.unlink('./test.json') if File.exist?('./test.json')
  end
end