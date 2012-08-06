require "eventmachine"
require "logger"
require "statsdserver/proto/v1"

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
        raise "@stats must be set" unless @stats

        begin
          StatsdServer::Proto::V1.parse(packet, @stats)
        rescue StatsdServer::Proto::ParseError => e
          @logger.warn(e.message)
        end
      end # def receive_data
    end # class Ucp
  end # class Input
end # class StatsdServer
