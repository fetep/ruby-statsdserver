class StatsdServer::Output
  class Tcp
    public
    def initialize(opts = {})
      if opts["host"].nil?
        raise ArgumentError, "missing host in [output:tcp]"
      end

      if opts["port"].nil?
        raise ArgumentError, "missing port in [output:tcp]"
      end

      @opts = opts
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
