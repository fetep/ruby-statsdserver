require "logger"
require "socket"

class StatsdServer::Output
  class Tcp
    attr_accessor :logger

    public
    def initialize(opts = {})
      if opts["host"].nil?
        raise ArgumentError, "missing host in [output:tcp] config section"
      end

      if opts["port"].nil?
        raise ArgumentError, "missing port in [output:tcp] config section"
      end

      @opts = opts
      @logger = Logger.new(STDOUT)
    end

    public
    def send(str)
      @socket ||= connect
      begin
        @socket.write("#{str}")
      rescue => e
        # set @socket to nil to force a re-connect, then pass up the exception
        @socket.close rescue nil
        @socket = nil
        raise
      end
    end

    private
    def connect
      TCPSocket.new(@opts["host"], @opts["port"].to_i)
    end
  end # class Tcp
end # class StatsdServer::Output
