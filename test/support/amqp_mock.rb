# In-memory AMQP/RabbitMQ mocks for testing without a real broker.
# Must be required BEFORE 'data_collector' so the real bunny/bunny_burrow gems are not loaded.

require 'json'
require 'ostruct'

module AMQPMock
  BLOCKED_REQUIRES = %w[bunny bunny_burrow].freeze

  class MessageBus
    @subscriptions = {}
    @mutex = Mutex.new

    class << self
      def subscribe(key, &block)
        @mutex.synchronize { @subscriptions[key] = block }
      end

      def publish(key, message)
        handler = @mutex.synchronize { @subscriptions[key] }
        handler&.call(message)
      end

      def reset!
        @mutex.synchronize { @subscriptions.clear }
      end
    end
  end

  class BunnyConnection
    def initialize(url)
      @url = url
      @open = false
    end

    def start
      @open = true
      self
    end

    def open?
      @open
    end

    def closed?
      !@open
    end

    def stop
      @open = false
    end

    def create_channel
      BunnyChannel.new
    end
  end

  class BunnyChannel
    def topic(name, **_opts)
      BunnyExchange.new(name)
    end

    def queue(name, **_opts)
      BunnyQueue.new(name)
    end
  end

  class BunnyExchange
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def publish(message, routing_key:)
      AMQPMock::MessageBus.publish("queue:#{@name}/#{routing_key}", message)
    end
  end

  class BunnyQueue
    def initialize(name)
      @name = name
      @bound_exchange = nil
    end

    def bind(exchange, routing_key: nil)
      @bound_exchange = exchange
      self
    end

    def subscribe(consumer_tag: nil, &block)
      exchange_name = @bound_exchange&.name
      AMQPMock::MessageBus.subscribe("queue:#{exchange_name}/#{@name}") do |payload|
        delivery_info = OpenStruct.new(routing_key: @name)
        metadata = OpenStruct.new
        block.call(delivery_info, metadata, payload)
      end
    end
  end
end

# Block real gem loading
original_require = method(:require)
define_method(:require) do |name|
  if AMQPMock::BLOCKED_REQUIRES.include?(name.to_s)
    true
  else
    original_require.call(name)
  end
end

# Mock Bunny module
module Bunny
  class ConnectionAlreadyClosed < StandardError; end

  def self.new(url)
    AMQPMock::BunnyConnection.new(url)
  end
end

# Mock BunnyBurrow module
module BunnyBurrow
  class Server
    attr_accessor :rabbitmq_url, :rabbitmq_exchange, :connection_name, :logger

    def initialize
      yield self if block_given?
    end

    def subscribe(queue_name, &block)
      key = "rpc:#{@rabbitmq_exchange}/#{queue_name}"
      AMQPMock::MessageBus.subscribe(key) do |payload|
        block.call(payload)
      end
    end

    def shutdown
      # no-op
    end

    def wait
      sleep 0.1
    end

    def self.create_response
      { status: 'ok' }
    end
  end

  class Client
    attr_accessor :rabbitmq_url, :rabbitmq_exchange, :connection_name, :logger

    def initialize
      yield self if block_given?
    end

    def publish(message, queue_name)
      key = "rpc:#{@rabbitmq_exchange}/#{queue_name}"
      response = AMQPMock::MessageBus.publish(key, message.to_json)
      response.to_json
    end

    def shutdown
      # no-op
    end
  end
end
