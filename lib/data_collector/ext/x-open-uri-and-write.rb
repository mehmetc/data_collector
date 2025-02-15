require 'stringio'
require 'uri'
require 'open-uri'
require 'net/dav'
require 'highline/import'

require 'open-uri-and-write/handle'
require 'open-uri-and-write/usernames'
require 'open-uri-and-write/credentials_store'
require_relative 'file'
require 'open-uri-and-write/dir_extensions'
#require 'open-uri-and-write/kernel_extensions'

# Kernel extensions
# Careful monkeypatching
module Kernel
  private
  alias open_uri_and_write_original open # :nodoc:

  def open(name, *rest, &block) # :doc:
    if name.respond_to?(:open)
      name.open(*rest, &block)
    elsif name.respond_to?(:to_s) and
      name.to_s[/^(https?):\/\//] and
      rest.size > 0 and
      rest.first.to_s[/^[rwa]/]
      webdav_agent = OpenUriAndWrite::Handle.new(name, rest)
      if(block)
        yield webdav_agent
      else
        return webdav_agent
      end
    else
      mode, options = rest
      options = {} unless options.is_a?(Hash)
      open_uri_and_write_original(name.to_s, mode, **options, &block)
    end
  end

  module_function :open
end

module OpenUriAndWrite
  class Handle < StringIO
    def write(string)
      if(@filemode[/^r/])
        raise IOError.new(true), "not opened for writing"
      end

      super(string)
      @dav.put_string(@url, string)
    end
  end
end
