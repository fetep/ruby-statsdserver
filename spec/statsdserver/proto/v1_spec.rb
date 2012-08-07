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

    it "should handle counters with a sampling rate" do
      update = "test.counter:2@0.1|c"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.counters["test.counter"].should eq(20)
    end

    it "should handle timers" do
      update = "test.timer:100|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([100])

      update = "test.timer:200|ms"
      StatsdServer::Proto::V1.parse_update(update, @stats)
      @stats.timers["test.timer"].should eq([100, 200])
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
