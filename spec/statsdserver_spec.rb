require "rubygems"
require "bundler/setup"

require "rspec/autorun"
require "statsdserver"
require "spec_helper"

describe StatsdServer do
  describe "#carbon_update_str" do
    it "should calculate rate for counters" do
      s = StatsdServer.new({:flush_interval => 10}, {}, {})
      s.stats.counters["test.counter"] = 5

      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.test.counter")
      res[1].should eq("0.5")
    end

    it "should send zeros for a known counter with no updates" do
      s = StatsdServer.new({}, {}, {})
      s.stats.counters["test.counter"] = 5

      res = s.carbon_update_str   # "flush" the test.counter rate
      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.test.counter")
      res[1].should eq("0.0")
    end

    it "should not send zeros for a known counter with no updates when preserve_counters is false" do
      s = StatsdServer.new({:preserve_counters => "false"}, {}, {})
      s.stats.counters["test.counter"] = 5

      res = s.carbon_update_str   # "flush" the test.counter rate
      res = s.carbon_update_str.should eq(nil)
    end

    it "should prepend prefix to metrics" do
      s = StatsdServer.new({:prefix => "foostatsd"}, {}, {})
      s.stats.counters["test.counter"] = 5
      res = s.carbon_update_str.split(" ")
      res[0].should eq("foostatsd.test.counter")
    end

    it "should append suffix to metrics" do
      s = StatsdServer.new({:suffix => "foo.bar"}, {}, {})
      s.stats.counters["test.counter"] = 5
      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.test.counter.foo.bar")
    end
  end
end
