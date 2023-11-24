require 'connection_pool'

module BunnyBurrow
  class Connection
    include Singleton
    attr_reader :connection, :started
    attr_accessor :verify_peer, :name, :rabbitmq_url

    def initialize
      super
      @started = false
    end
    def connection
      @connection ||= Bunny.new(@rabbitmq_url, verify_peer: @verify_peer, connection_name: @name)
      unless @started
        @connection.start
        @started = true
      end

      @connection
    end

    def channel
      @channel ||= ConnectionPool::Wrapper.new do
        connection.create_channel
      end
    end
  end

  class Base
    attr_accessor(
      :name
    )

    private

    def connection
      Connection.instance.name = @name
      Connection.instance.verify_peer = @verify_peer
      Connection.instance.rabbitmq_url = @rabbitmq_url

      unless @connection
        @connection = Connection.instance.connection
      end

      @connection
    end

    def channel
      Connection.instance.name = @name
      Connection.instance.verify_peer = @verify_peer
      Connection.instance.rabbitmq_url = @rabbitmq_url

      @channel ||= Connection.instance.channel
    end
  end
end

