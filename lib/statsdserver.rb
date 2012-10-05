require "logger"
require "statsdserver/input/udp"
require "statsdserver/input/zeromq"
require "statsdserver/math"
require "statsdserver/stats"

# Hack because the latest amqp gem uses String#bytesize, and not everyone
# is running ruby 1.8.7.
if !String.instance_methods.include?(:bytesize)
  class String
    alias :bytesize :length
  end
end

class StatsdServer
  attr_accessor :logger
  attr_accessor :stats

  public
  def initialize(opts, input_config, output_config)
    @stats = StatsdServer::Stats.new
    @logger = Logger.new(STDERR)
    @logger.progname = File.basename($0)

    @opts = {
      :bind => "127.0.0.1",
      :port => 8125,
      :percentile => 90,
      :flush_interval => 30,
      :prefix => "stats",
      :preserve_counters => "true",
    }.merge(opts)
    @input_config = input_config
    @output_config = output_config

    # argument checking
    [:port, :percentile, :flush_interval].each do |key|
      begin
        @opts[key] = Float(@opts[key])
      rescue
        raise "#{key}: #{@opts[key].inspect}: must be a valid number"
      end
    end
  end # def initialize

  public
  def run
    # initialize outputs
    @outputs = []
    @output_config.each do |output, config|
      klass = StatsdServer::Output.const_get(output.capitalize)
      if klass.nil?
        @logger.fatal("unknown output #{output.inspect}")
        exit EX_DATAERR
      end
      @outputs << klass.new(config)
    end # @output_config.each

    # start inputs
    @input_config.each do |input, config|
      case input
      when "udp"
        EM.open_datagram_socket(config["bind"], config["port"].to_i,
                                Input::Udp) do |s|
          s.logger = @logger
          s.stats = @stats
        end # EM.open_datagram_socket
      when "zeromq"
        s = Input::ZeroMQ.new
        s.logger = @logger
        s.stats = @stats
        $ctx = EM::ZeroMQ::Context.new(1)
        sock = $ctx.socket(ZMQ::PULL, s)
        sock.setsockopt(ZMQ::HWM, 100)
        sock.bind(config["bind"])
      else
        @logger.fatal("unknown input #{input.inspect}")
        exit EX_DATAERR
      end # case input
    end # @inputs.each

    # start flusher
    Thread.abort_on_exception = true
    @flusher = Thread.new do
      while sleep(@opts[:flush_interval])
        begin
          flush
        rescue => e
          @logger.warn("trouble flushing: #{$!}")
          @logger.debug(e.backtrace.join("\n"))
        end
      end
    end
  end # def run

  #private
  #def setup_amqp
  #  begin
  #    require "amqp"
  #  rescue LoadError
  #    @logger.fatal("missing amqp ruby module. try gem install amqp")
  #    exit(1)
  #  end
#
#    user = @output_url.user || ""
#    user, vhost = user.split("@", 2)
#    _, mqtype, mqname = @output_url.path.split("/", 3)
#    amqp_settings = {
#      :host => @output_url.host,
#      :port => @output_url.port || 5672,
#      :user => user,
#      :pass => @output_url.password,
#      :vhost => vhost || "/",
#    }
#
#
#    @amqp = AMQP.connect(amqp_settings)
#    @channel = AMQP::Channel.new(@amqp)
#
#    opts = {
#      :durable => true,
#      :auto_delete => false,
#    }
#
#    if @output_url.query
#      @output_url.query.split("&").each do |param|
#        k, v = param.split("=", 2)
#        opts[:durable] = false if k == "durable" and v == "false"
#        opts[:auto_delete] = true if k == "autodelete" and v == "true"
#      end
#    end
#
#    @exchange = case mqtype
#    when "fanout"
#      @channel.fanout(mqname, opts)
#    when "direct"
#      @channel.exchange(mqname, opts)
#    when "topic"
#      @channel.topic(mqname, opts)
#    else
#      raise TypeError, "unknown amqp output type #{mqtype}"
#    end
#  end # def setup_amqp

  private
  def metric_name(name)
    if @opts[:prefix] && !@opts[:prefix].empty?
      prefix = @opts[:prefix] + "."
    else
      prefix = ""
    end

    if @opts[:suffix] && !@opts[:suffix].empty?
      suffix = "." + @opts[:suffix]
    else
      suffix = ""
    end

    return [prefix, name, suffix].join("")
  end

  public
  def carbon_update_str
    updates = []
    now = Time.now.to_i

    timers = {}
    @stats.timers.keys.each do |k|
      timers[k] = @stats.timers.delete(k)
    end

    counters = {}
    @stats.counters.keys.each do |k|
      counters[k] = @stats.counters.delete(k)
    end

    if @opts[:preserve_counters] == "true"
      # Keep sending a 0 for counters (even if we don't get updates)
      counters.keys.each do |k|
        @stats.counters[k] ||= 0    # Keep sending a 0 if we don't get updates
      end
    end

    timers.each do |key, values|
      next if values.length == 0
      summary = ::StatsdServer::Math.summarize(values, @opts)

      updates << [metric_name("timers.#{key}.mean"),
                  summary[:mean], now].join(" ")
      updates << [metric_name("timers.#{key}.upper"),
                  summary[:max], now].join(" ")
      updates << [metric_name("timers.#{key}.lower"),
                  summary[:min], now].join(" ")
      updates << [metric_name("timers.#{key}.count"),
                  values.length, now].join(" ")
      updates << [metric_name("timers.#{key}.upper_#{@opts[:percentile].to_i}"),
                  summary[:max_at_threshold], now].join(" ")
    end # timers.each

    counters.each do |key, value|
      updates << [metric_name(key),
                  value / @opts[:flush_interval],
                  now].join(" ")
    end # counters.each

    return updates.length == 0 ? nil : updates.join("\n") + "\n"
  end # def carbon_update_str

  public
  def flush
    s = carbon_update_str
    return unless s

    if @outputs.nil? or @outputs.length == 0
      @logger.warn("no outputs configured, can't flush data")
      return
    end

    @outputs.each do |output|
      output.send(s)
    end
  end # def flush
end # class StatsdServer
