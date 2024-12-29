require_relative 'data_collector/ext/x-open-uri-and-write'

class ProxyLogger
  attr_reader :targets
  def initialize(*targets)
    @targets = targets.flatten
  end

  def write(*args)
    @targets.each do |t|
      t.write(*args)
    end
  end

  def close
    @targets.each(&:close)
  end
end