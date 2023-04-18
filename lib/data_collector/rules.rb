require_relative 'rules_ng'

module DataCollector
  class Rules < RulesNg
    def initialize(logger =  Logger.new(STDOUT))
      super
    end
  end
end
