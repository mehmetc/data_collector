$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "data_collector"
include DataCollector::Core

require "minitest/autorun"