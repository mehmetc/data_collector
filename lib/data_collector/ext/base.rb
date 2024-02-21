require 'securerandom'
#require 'connection_pool'

module BunnyBurrow
  # class Connection
  #   include Singleton
  #   attr_reader :connection
  #   attr_accessor :verify_peer, :connection_name, :rabbitmq_url
  #
  #   def connection
  #     unless @connection
  #       @connection = Bunny.new(@rabbitmq_url, verify_peer: @verify_peer, connection_name: @connection_name)
  #       @connection.start
  #     end
  #
  #     @connection.start unless @connection.connected? || @connection.closed?
  #     #@connection.start if @connection.closed?
  #
  #     #pp @connection.status
  #
  #     @connection
  #   end
  #
  #   def channel
  #     @channel = connection.create_channel unless @channel && @channel.open?
  #
  #     @channel
  #   end
  # end

  class Base
    attr_accessor(
      :connection_name
    )

    # def initialize
    #   super
    #   @connection_name = "#{Process.pid}-#{SecureRandom.uuid}"
    # end
  #   private
  #
  #   def connection
  #     Connection.instance.connection_name = @connection_name
  #     Connection.instance.verify_peer = @verify_peer
  #     Connection.instance.rabbitmq_url = @rabbitmq_url
  #
  #     unless @connection
  #       @connection = Connection.instance.connection
  #       @connection.start unless @connection.open?
  #     end
  #
  #     @connection
  #   end
  #
  #   def channel
  #     Connection.instance.connection_name = @connection_name
  #     Connection.instance.verify_peer = @verify_peer
  #     Connection.instance.rabbitmq_url = @rabbitmq_url
  #
  #     @channel = Connection.instance.channel
  #   end
  end
end

