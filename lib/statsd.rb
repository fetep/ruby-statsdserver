#!/usr/bin/ruby

require "rubygems"
require "eventmachine"
require "socket"

module StatsD
  @@timers = Hash.new { |h, k| h[k] = Array.new }
  @@counters = Hash.new { |h, k| h[k] = 0 }
  @@flush_interval = 10
  @@pct_threshold = 90

  def self.flush_interval=(val)
    @@flush_interval = val.to_i
  end

  def self.pct_threshold=(val)
    @@pct_threshold = val.to_i
  end

  def receive_data(packet)
    bits = packet.split(":")
    key = bits.shift.gsub(/\s+/, "_") \
                    .gsub(/\//, "-") \
                    .gsub(/[^a-zA-Z_\-0-9\.]/, "")
    bits << "1" if bits.length == 0
    bits.each do |bit|
      fields = bit.split("|")
      if fields.length != 2
        $stderr.puts "invalid update: #{bit}"
        next
      end

      if fields[1] == "ms" # timer update
        @@timers[key] << fields[0].to_f
      elsif fields[1] == "c" # counter update
        count, sample_rate = fields[0].split("@", 2)
        sample_rate ||= 1
        #puts "count is #{count.to_f} (#{count})"
        #puts "multiplier is is #{1 / sample_rate.to_f}"
        @@counters[key] += count.to_f * (1 / sample_rate.to_f)
      else
        $stderr.puts "invalid field in update: #{bit}"
      end
    end
  end

  def self.carbon_update_str
    updates = []
    now = Time.now.to_i

    @@timers.each do |key, values|
      values.sort!
      min = values[0]
      max = values[-1]
      mean = min
      maxAtThreshold = min
      if values.length > 1
        threshold_index = ((100 - @@pct_threshold) / 100.0) * values.length
        threshold_count = values.length - threshold_index.round
        valid_values = values.slice(0, threshold_count)
        maxAtThreshold = valid_values[-1]

        sum = 0
        valid_values.each { |v| sum += v }
        mean = sum / valid_values.length
      end

      updates << "stats.timers.#{key}.mean #{mean} #{now}"
      updates << "stats.timers.#{key}.upper #{max} #{now}"
      updates << "stats.timers.#{key}.upper_#{@@pct_threshold} " \
                 "#{maxAtThreshold} #{now}"
      updates << "stats.timers.#{key}.lower #{min} #{now}"
      updates << "stats.timers.#{key}.count #{values.length} #{now}"
    end

    @@counters.each do |key, value|
      updates << "stats.#{key} #{value / @@flush_interval} #{now}"
    end

    @@timers.each { |k, v| @@timers[k] = [] }
    @@counters.each { |k, v| @@counters[k] = 0 }
  
    return updates.length == 0 ? nil : updates.join("\n") + "\n"
  end

  def self.flush
    puts carbon_update_str
  end
end
