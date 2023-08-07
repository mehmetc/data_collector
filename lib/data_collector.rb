#encoding: UTF-8
require 'active_support/core_ext/hash'
require 'logger'

require 'data_collector/version'
require 'data_collector/runner'
require 'data_collector/pipeline'
require 'data_collector/ext/xml_utility_node'

module DataCollector
  class Error < StandardError; end

  class InputError < DataCollector::Error; end
end
