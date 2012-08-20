require "logger"
require "bunny"

class StatsdServer::Output
  class Amqp
    attr_accessor :logger

    public
    def initialize(opts = {})
      if opts["exchange_type"].nil?
        raise ArgumentError, "missing host in [output:tcp] config section"
      end

      if opts["exchange_name"].nil?
        raise ArgumentError, "missing port in [output:tcp] config section"
      end

      @opts = opts
      @logger = Logger.new(STDOUT)
    end

    public
    def send(str)
      if @bunny.nil?
        @bunny, @exchange = connect
      end

      begin
        @exchange.publish(str)
      rescue => e
        @bunny.close_connection rescue nil
        @bunny = nil
        raise
      end
    end

    private
    def connect
      bunny = Bunny.new(@opts)
      bunny.start

      exchange = bunny.exchange(
        @opts["exchange_name"],
        :type => @opts["exchange_type"].to_sym,
        :durable => @opts["exchange_durable"] == "true" ? true : false,
        :auto_delete => @opts["exchange_auto_delete"] == "true" ? true : false,
      )

      return bunny, exchange
    end
  end # class Amqp
end # class StatsdServer::Output
