require "rubygems"
require "bundler/setup"

require "rspec/autorun"
require "spec_helper"
require "statsdserver/proto/v1"

describe StatsdServer::Proto::V1 do
  describe ".parse_update" do
    it "should handle counters" do
      update = "test.counter:1|c"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.counters["test.counter"].should eq(1)

      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.counters["test.counter"].should eq(2)

      update = "test.counter:5|c"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.counters["test.counter"].should eq(7)
    end

    it "should handle invalid counters" do
      update = "test.counter:monkey|c"
      lambda { StatsdServer::Proto::V1.parse_update(update, @stats) }.should \
        raise_error(StatsdServer::Proto::ParseError, "invalid count: monkey")
      @stats.counters.keys.should eq([])
    end

    it "should handle counters with a sampling rate" do
      update = "test.counter:2@0.1|c"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.counters["test.counter"].should eq(20)
    end

    it "should handle counters with an invalid sampling rate" do
      update = "test.counter:2@brains|c"
      lambda { StatsdServer::Proto::V1.parse_update(update, @stats) }.should \
        raise_error(StatsdServer::Proto::ParseError,
                    "invalid sample_rate: brains")
      @stats.counters.keys.should eq([])
    end

    it "should handle timers with type ms" do
      update = "test.timer:100|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([100])

      update = "test.timer:200|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([100, 200])
    end

    it "should handle timers with type t" do
      update = "test.timer:100|t"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([100])

      update = "test.timer:200|t"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([100, 200])
    end

    it "should handle timers with invalid updates" do
      update = "test.timer:unicorn|ms"
      lambda { StatsdServer::Proto::V1.parse_update(update, @stats) }.should \
        raise_error(StatsdServer::Proto::ParseError,
                    "invalid timer value: unicorn")
      @stats.timers.keys.should eq([])
    end

    it "should handle timers with multiple updates" do
      update = "test.timer:10,20,30|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([10, 20, 30])
    end

    it "should handle timers with multiple updates and missing values" do
      update = "test.timer:10,,20,30|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([10, 20, 30])
      @stats.timers.delete("test.timer")

      update = "test.timer:10,20,30,|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([10, 20, 30])
      @stats.timers.delete("test.timer")

      update = "test.timer:,10,20,30|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([10, 20, 30])
      @stats.timers.delete("test.timer")
    end

    it "should handle gauges" do
      update = "test.gauge:1|g"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.gauges["test.gauge"].should eq(1)

      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.gauges["test.gauge"].should eq(2)

      update = "test.gauge:5|g"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.gauges["test.gauge"].should eq(7)
    end

    it "should handle invalid gauges" do
      update = "test.gauge:donkey|g"
      lambda { StatsdServer::Proto::V1.parse_update(update, @stats) }.should \
        raise_error(StatsdServer::Proto::ParseError, "invalid count: donkey")
      @stats.gauges.keys.should eq([])
    end

  end

  describe ".parse" do
    it "should split on \n and treat each line as an update" do
      update = [
        "test.counter:1|c",
        "test.counter2:1|c",
      ].join("\n")

      StatsdServer::Proto::V1.parse(update, @stats)
      @stats.counters["test.counter"].should eq(1)
      @stats.counters["test.counter2"].should eq(1)
    end
  end
end
