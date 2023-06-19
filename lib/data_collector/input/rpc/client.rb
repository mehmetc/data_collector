require 'bunny'
require 'thread'
require_relative '../rpc'

module DataCollector
  class Input
    class Rpc
      class Client < DataCollector::Input::Rpc


        private
        def reply_queue
          @lock = Mutex.new
          @token = ConditionVariable.new

        end

      end
    end
  end
end