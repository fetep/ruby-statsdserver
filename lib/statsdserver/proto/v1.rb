require "statsdserver/proto/parseerror"

class StatsdServer
  class Proto
    module V1
      def self.parse(data, stats)
        data.split("\n").each do |update|
          self.parse_update(update, stats)
        end
      end # def parse

      def self.parse_update(update, stats)
        bits = update.split(":")
        # TODO: optimize into single regexp & compile?
        key = bits.shift.gsub(/\s+/, "_") \
                .gsub(/\//, "-") \
                .gsub(/[^a-zA-Z_\-0-9\.]/, "")
        bits << "1" if bits.length == 0
        bits.each do |bit|
          fields = bit.split("|")
          if fields.length != 2
            raise ParseError, "invalid update: #{bit}"
          end

          if fields[1] == "ms" # timer update
            stats.timers[key] << fields[0].to_f
          elsif fields[1] == "c" # counter update
            count, sample_rate = fields[0].split("@", 2)
            sample_rate ||= 1
            stats.counters[key] += count.to_f * (1 / sample_rate.to_f)
          else
            raise ParseError,
                  "invalid update: #{update}: unknown type #{fields[1]}"
          end
        end
      end # def parse_update
    end # module V1
  end # class Proto
end # class StatsdServer
