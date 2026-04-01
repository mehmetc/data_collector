require 'test_helper'

# Mock WebDAV connection returned by OpenUriAndWrite::CredentialsStore
module MockWebDAV
  class Connection
    attr_reader :calls

    def initialize
      @calls = []
    end

    def exist?(url)
      @calls << [:exist?, url]
      true
    end

    def delete(url)
      @calls << [:delete, url]
    end

    def mkdir(url)
      @calls << [:mkdir, url]
    end

    def put_string(url, content)
      @calls << [:put_string, url, content]
    end

    def propfind(url, *args)
      @calls << [:propfind, url, *args]
      '<xml>properties</xml>'
    end
  end
end

class DataCollectorFileDirTest < Minitest::Test

  def setup
    @mock_dav = MockWebDAV::Connection.new

    # Stub CredentialsStore to return our mock DAV connection
    OpenUriAndWrite::CredentialsStore.instance_variable_set(:@mock_dav_instance, @mock_dav)
    OpenUriAndWrite::CredentialsStore.define_singleton_method(:get_connection_for_url) do |_url|
      @mock_dav_instance
    end

    # Stub Handle.new to avoid interactive credential prompts (HighLine)
    @original_handle_new = OpenUriAndWrite::Handle.method(:new)
    mock_dav = @mock_dav
    OpenUriAndWrite::Handle.define_singleton_method(:new) do |url, rest = []|
      handle = StringIO.new
      handle.define_singleton_method(:url) { url }
      handle.define_singleton_method(:write) do |string|
        super(string)
        mock_dav.put_string(url, string)
      end
      handle
    end
  end

  def teardown
    # Restore original Handle.new
    original = @original_handle_new
    OpenUriAndWrite::Handle.define_singleton_method(:new) do |*args|
      original.call(*args)
    end
  end

  # ---- File.exist? ----

  def test_file_exist_local
    assert_equal(true, File.exist?('test/fixtures/test.csv'))
  end

  def test_file_exist_local_missing
    assert_equal(false, File.exist?('test/fixtures/nonexistent_file.csv'))
  end

  def test_file_exist_http_url
    result = File.exist?('https://example.com/remote/file.txt')

    assert_equal(true, result)
    assert_equal(:exist?, @mock_dav.calls.last.first)
    assert_equal('https://example.com/remote/file.txt', @mock_dav.calls.last[1])
  end

  # ---- File.delete ----

  def test_file_delete_local
    tmpfile = 'test/fixtures/tmp_delete_test.txt'
    File.original_open(tmpfile, 'w') { |f| f.write('temp') }
    assert_equal(true, File.exist?(tmpfile))

    File.delete(tmpfile)
    assert_equal(false, File.original_exist?(tmpfile))
  end

  def test_file_delete_http_url
    File.delete('https://example.com/remote/file.txt')

    assert_equal(:delete, @mock_dav.calls.last.first)
    assert_equal('https://example.com/remote/file.txt', @mock_dav.calls.last[1])
  end

  # ---- File.open ----

  def test_file_open_local_read
    content = File.open('test/fixtures/test.csv', 'r') { |f| f.read }
    assert_kind_of(String, content)
    refute_empty(content)
  end

  def test_file_open_local_write
    tmpfile = 'test/fixtures/tmp_open_write_test.txt'
    begin
      File.open(tmpfile, 'wb:UTF-8') { |f| f.write('hello') }
      assert_equal('hello', File.read(tmpfile))
    ensure
      File.original_delete(tmpfile) if File.original_exist?(tmpfile)
    end
  end

  def test_file_open_http_url_write_mode
    handle = File.open('https://example.com/remote/file.txt', 'w')
    assert_kind_of(StringIO, handle)
  end

  def test_file_open_http_url_write_with_block
    written = nil
    File.open('https://example.com/remote/file.txt', 'w') do |f|
      f.write('hello webdav')
      written = true
    end

    assert_equal(true, written)
    assert_equal(:put_string, @mock_dav.calls.last.first)
    assert_equal('hello webdav', @mock_dav.calls.last[2])
  end

  # ---- Dir.mkdir ----

  def test_dir_mkdir_local
    tmpdir = 'test/fixtures/tmp_test_dir'
    begin
      Dir.mkdir(tmpdir)
      assert_equal(true, File.directory?(tmpdir))
    ensure
      Dir.original_rmdir(tmpdir) if File.directory?(tmpdir)
    end
  end

  def test_dir_mkdir_http_url
    Dir.mkdir('https://example.com/remote/newdir/')

    assert_equal(:mkdir, @mock_dav.calls.last.first)
    assert_equal('https://example.com/remote/newdir/', @mock_dav.calls.last[1])
  end

  # ---- Dir.rmdir ----

  def test_dir_rmdir_local
    tmpdir = 'test/fixtures/tmp_rmdir_test'
    Dir.original_mkdir(tmpdir)
    assert_equal(true, File.directory?(tmpdir))

    Dir.rmdir(tmpdir)
    assert_equal(false, File.directory?(tmpdir))
  end

  def test_dir_rmdir_http_url
    Dir.rmdir('https://example.com/remote/olddir/')

    assert_equal(:delete, @mock_dav.calls.last.first)
    assert_equal('https://example.com/remote/olddir/', @mock_dav.calls.last[1])
  end

  # ---- Dir.propfind ----

  def test_dir_propfind_http_url
    result = Dir.propfind('https://example.com/remote/dir/')

    assert_equal('<xml>properties</xml>', result)
    assert_equal(:propfind, @mock_dav.calls.last.first)
    assert_equal('https://example.com/remote/dir/', @mock_dav.calls.last[1])
  end

  def test_dir_propfind_local_raises
    assert_raises(IOError) do
      Dir.propfind('/tmp/local_dir')
    end
  end

  # ---- Dir.proppatch ----

  def test_dir_proppatch_http_url
    xml = '<set><prop><author>test</author></prop></set>'
    Dir.proppatch('https://example.com/remote/dir/', xml)

    assert_equal(:propfind, @mock_dav.calls.last.first)
    assert_equal('https://example.com/remote/dir/', @mock_dav.calls.last[1])
    assert_equal(xml, @mock_dav.calls.last[2])
  end

  def test_dir_proppatch_local_raises
    assert_raises(IOError) do
      Dir.proppatch('/tmp/local_dir', '<xml/>')
    end
  end
end
