#!/usr/bin/env ruby

require "test/unit"
require "statsd"

class CounterTest < Test::Unit::TestCase
  include StatsD

  def setup
    @data = [30, 40, 30, 40]
    @key = "test.counter"
    StatsD.flush_interval = 10
  end

  def test_counters
    @data.each { |v| receive_data("#{@key}:#{v}|c") }
    parts = StatsD.carbon_update_str.split(" ")
    assert_equal("stats.#{@key}", parts[0])
    assert_equal("14.0", parts[1])
  end

  def test_counters_flush_interval
    StatsD.flush_interval = 5
    @data.each { |v| receive_data("#{@key}:#{v}|c") }
    parts = StatsD.carbon_update_str.split(" ")
    assert_equal("stats.#{@key}", parts[0])
    assert_equal("28.0", parts[1])
  end

  def test_counters_multiple_values_in_one_packet
    packet = "#{@key}:" + @data.collect { |v| "#{v}|c" }.join(":")
    receive_data(packet)
    parts = StatsD.carbon_update_str.split(" ")
    assert_equal("stats.#{@key}", parts[0])
    assert_equal("14.0", parts[1])
  end

  def test_counters_zero
    @data.each { |v| receive_data("#{@key}:#{v}|c") }
    StatsD.carbon_update_str
    parts = StatsD.carbon_update_str.split(" ")
    assert_equal("stats.#{@key}", parts[0])
    assert_equal("0", parts[1])
  end

  def test_counters_scaling
    @data.each { |v| receive_data("#{@key}:#{v}@.1|c") }
    parts = StatsD.carbon_update_str.split(" ")
    assert_equal("stats.#{@key}", parts[0])
    assert_equal("140.0", parts[1])
  end
end
