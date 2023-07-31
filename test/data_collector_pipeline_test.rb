require "test_helper"

class DataCollectorPipelineTest < Minitest::Test

  def test_pipeline_setup
    pipeline = DataCollector::Pipeline.new
    pipeline.on_message do |input, output|
      puts "on_message"
    end

    assert_equal(pipeline.running?, false)
    assert_equal(pipeline.stopped?, true)
    pipeline.run
    assert_equal(pipeline.running?, true)
    pipeline.pause
    assert_equal(pipeline.running?, true)
    assert_equal(pipeline.paused?, true)
    assert_equal(pipeline.stopped?, false)
    pipeline.run
    assert_equal(pipeline.running?, true)
    assert_equal(pipeline.paused?, false)
    assert_equal(pipeline.stopped?, false)
    pipeline.stop
    assert_equal(pipeline.running?, false)
    assert_equal(pipeline.stopped?, true)
    assert_equal(pipeline.paused?, false)

    assert_equal(2, pipeline.run_count)
  end

  def test_scheduled_pipeline
    counter = 0
    pipeline = DataCollector::Pipeline.new(schedule: 'PT2S')
    pipeline.on_message do |input, output|
      count = output.key?(:counter) ? output[:counter] : 0
      output[:counter] = count + 1
      counter = output[:counter]
      pipeline.stop if output[:counter] >= 2
    end
    pipeline.run

    assert_equal(2, counter)
  end

  def test_bad_schedule
    pipeline = DataCollector::Pipeline.new(schedule: 'Blabla')
    error = assert_raises(DataCollector::Error) do
      pipeline.run
    end

    assert_equal('PIPELINE - bad schedule: Unknown pattern Blabla', error.message)
  end

  def test_scheduled_cron_pipeline
    counter = 0
    time = Time.now + 60
    hour = time.hour
    minutes = time.min

    pipeline = DataCollector::Pipeline.new(cron: "#{minutes} #{hour} * * *")
    pipeline.on_message do |input, output|
      log('trigger cron')
      count = output.key?(:counter) ? output[:counter] : 0
      output[:counter] = count + 1
      counter = output[:counter]
      pipeline.stop if output[:counter] >= 1
    end
    pipeline.run

    assert_equal(1, counter)
  end


end