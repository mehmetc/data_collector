$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require_relative 'support/amqp_mock'
require "data_collector"
include DataCollector::Core

require "minitest/autorun"