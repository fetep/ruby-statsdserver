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
      @socket.write("#{str}\n")
    end

    private
    def connect
      TCPSocket.new(@opts["host"], @opts["port"].to_i)
    end
  end # class Tcp
end # class StatsdServer::Output
