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

          if fields[1] == "ms" or fields[1] == "t" # timer update
            if fields[0].index(",")
              fields[0].split(",").each do |value_str|
                value = Integer(value_str) rescue nil
                stats.timers[key] << value if value
              end
            else
              value = Integer(fields[0]) rescue nil
              if value.nil?
                raise ParseError, "invalid timer value: #{fields[0]}"
              end
              stats.timers[key] << fields[0].to_i
            end

          elsif fields[1] == "c" # counter update
            count_str, sample_rate_str = fields[0].split("@", 2)

            if sample_rate_str
              sample_rate = Float(sample_rate_str) rescue nil
              if sample_rate.nil?
                raise ParseError, "invalid sample_rate: #{sample_rate_str}"
              end
            else
              sample_rate = 1
            end

            count = Integer(count_str) rescue nil
            if count.nil?
              raise ParseError, "invalid count: #{count_str}"
            end

            stats.counters[key] += count.to_i * (1 / sample_rate.to_f)
            
          elsif fields[1] == "g" # gauge update
            value = Float(fields[0]) rescue nil
            if value.nil?
              raise ParseError, "invalid gauge value: #{fields[0]}"
            end

            stats.gauges[key] << fields[0].to_i

          else
            raise ParseError,
                  "invalid update: #{update}: unknown type #{fields[1]}"
          end
        end
      end # def parse_update
    end # module V1
  end # class Proto
end # class StatsdServer
