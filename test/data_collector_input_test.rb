require 'test_helper'
require 'webmock/minitest'

include WebMock::API
WebMock.enable!

class DataCollectorInputTest < Minitest::Test
  def test_input_from_uri_file
    data = DataCollector::Input.new.from_uri('file://test/fixtures/test.csv')

    assert_equal(3, data.size)
  end

  def test_input_from_uri_file_non_standard_uri
    data = DataCollector::Input.new.from_uri("file://test/fixtures/test[123].csv")
    assert_equal(3, data.size)
  end

  def test_input_from_uri_http
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
  def test_input_from_tar
    sequence = 0
    DataCollector::Input.new.from_uri("file://test/fixtures/test.tar.gz") do |data|
      assert_equal(true, data.key?('data'))
      assert_equal(true, data['data'].key?('item'))
      pp data
      sequence += 1
    end
    assert_equal(2, sequence)
  end

  def test_input_from_with_block
    DataCollector::Input.new.from_uri("file://test/fixtures/test.csv") do |data|
      puts data
      assert_equal(["1", "2", "3"], data.map{|m| m[:sequence]})
    end
  end

  def test_input_from_html_file
    DataCollector::Input.new.from_uri("file://test/fixtures/test.html") do |data|
      pp data
      assert_equal(1, data.size)
      assert_includes(data[0], :div)
      assert_includes(data[0][:div], :id)
      assert_includes(DataCollector::Core.filter(data, '$..span').first, 'children')

    end
  end

  def test_input_image_with_block
    stub_request(:get, "https://upload.wikimedia.org/wikipedia/commons/4/47/PiLposterforWikipedia.jpg").
      with(
        headers: {
          'Connection'=>'close',
          'Host'=>'upload.wikimedia.org',
          'User-Agent' => 'http.rb/5.2.0'
        }).
      to_return(status: 200, body: "", headers: {'Content-Type': 'image/jpg'})

    DataCollector::Input.new.from_uri("file://test/fixtures/test.png") do |data|
      assert_equal('data:image/png;', data[0..14])
    end

    DataCollector::Input.new.from_uri("https://upload.wikimedia.org/wikipedia/commons/4/47/PiLposterforWikipedia.jpg") do |data|
      assert_equal('data:image/jpg;', data[0..14])
    end


  end

  def test_input_stringio
    i=DataCollector::Input.new
    a='{"a":1}'
    c = i.from_uri(StringIO.new(a), content_type: 'application/json')

    assert_equal(1, c['a'])
  end

  def test_input_stringio_shacl
    i=DataCollector::Input.new
    shacl = %(
@prefix example: <https://example.com/> .
@prefix xsd:    <http://www.w3.org/2001/XMLSchema#> .
@prefix sh:     <http://www.w3.org/ns/shacl#> .

example:CarShape
        a sh:NodeShape;
        sh:description  "Abstract shape that describes a car entity" ;
        sh:targetClass  example:Car;
        sh:node         example:Car;
        sh:name         "Car";
        sh:property     [ sh:path        example:color ;
                          sh:name        "color" ;
                          sh:description "Color of the car" ;
                          sh:datatype    xsd:string ;
                          sh:minCount    1 ;
                          sh:maxCount    1 ; ];
        sh:property     [ sh:path        example:brand ;
                          sh:name        "brand" ;
                          sh:description "Brand of the car" ;
                          sh:datatype    xsd:string ;
                          sh:minCount    1 ;
                          sh:maxCount    1 ; ] .
)
    c = i.from_uri(StringIO.new(shacl), content_type: 'text/turtle')
    assert_kind_of(Hash, c)
    assert_includes(c.keys, '@context')
    assert_includes(c.keys, '@graph')
    assert_kind_of(Array, c['@graph'])
    assert_equal(3, c['@graph'].size)
    assert_includes(c['@graph'].map{|m| m['sh:name']}, 'Car')
    assert_includes(c['@graph'].map{|m| m['sh:name']}, 'color')
    assert_includes(c['@graph'].map{|m| m['sh:name']}, 'brand')
  end

  def test_input_stringio_no_content_type
    i=DataCollector::Input.new
    a='{"a":1}'

    assert_raises(DataCollector::InputError) do
      c = i.from_uri(StringIO.new(a))
    end
  end

end