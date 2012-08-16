require "logger"

class StatsdServer
  module Math
    def self.summarize(values, opts)
      res = {}
      values.sort!

      res[:min] = values[0]
      res[:max] = values[-1]
      res[:mean] = min
      res[:max_at_threshold] = min
      if values.length > 1
        threshold_index = ((100 - opts[:percentile]) / 100.0) * values.length
        threshold_count = values.length - threshold_index.round
        valid_values = values.slice(0, threshold_count)
        res[:max_at_threshold] = valid_values[-1]
        sum = 0
        valid_values.each { |v| sum += v }
        res[:mean] = sum / valid_values.length
      end

      return res
    end

  end # class Math
end # class StatsdServer
