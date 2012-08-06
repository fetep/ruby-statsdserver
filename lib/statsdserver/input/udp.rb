require "eventmachine"
require "logger"

class StatsdServer
  class Input
    class Udp < EventMachine::Connection
      attr_accessor :logger,
                    :stats

      public
      def initialize
        @logger = Logger.new(STDOUT)
      end

      public
      def receive_data(packet)
        packet.chomp!
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
            @stats.timers[key] << fields[0].to_f
          elsif fields[1] == "c" # counter update
            count, sample_rate = fields[0].split("@", 2)
            sample_rate ||= 1
            @stats.counters[key] += count.to_f * (1 / sample_rate.to_f)
          else
            @logger.warn("invalid update (#{packet}): unkown type #{fields[1]}")
          end
        end
      end # def receive_data
    end # class Ucp
  end # class Input
end # class StatsdServer
