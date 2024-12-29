require 'open-uri-and-write'

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