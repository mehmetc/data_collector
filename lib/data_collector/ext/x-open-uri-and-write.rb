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
require 'open-uri-and-write/kernel_extensions'

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
