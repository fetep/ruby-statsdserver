require "logger"
require "statsdserver/proto/v1"

class StatsdServer
  class Input
    class ZeroMQ
      attr_accessor :logger,
                    :stats

      public
      def initialize
        begin
          require "em-zeromq"
        rescue LoadError => e
          raise unless e.message =~ /em-zeromq/
          new_e = \
            e.exception("Please install the em-zeromq gem for ZeroMQ input.")
          new_e.set_backtrace(e.backtrace)
          raise new_e
        end

        @logger = Logger.new(STDOUT)
      end

      public
      def on_readable(socket, parts)
        parts.each do |part|
          str = part.copy_out_string
          receive_data(str)
        end
      end

      public
      def receive_data(packet)
        raise "@stats must be set" unless @stats

        sep = packet.index(";")
        if sep.nil?
          @logger.warn("received unversioned update: #{packet}")
          return
        end

        proto_ver = packet[0 .. sep - 1]
        payload = packet[sep + 1 .. -1]
        case proto_ver
        when "1"
          begin
            StatsdServer::Proto::V1.parse(payload, @stats)
          rescue StatsdServer::Proto::ParseError => e
            @logger.warn(e.message)
          end
        else
          @logger.warn("unknown protocol version #{proto_ver} in update #{packet}")
          return
        end

      end # def receive_data
    end # class Ucp
  end # class Input
end # class StatsdServer
