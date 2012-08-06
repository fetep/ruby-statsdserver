require "logger"
require "statsdserver/input/udp"
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
      :prefix => "stats"
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
      else
        @logger.fatal("unknown input #{input.inspect}")
        exit EX_DATAERR
      end # case input
    end # @inputs.each

    # start flusher
    EM.add_periodic_timer(@opts[:flush_interval]) do
      EM.defer do
        begin
          flush
        rescue => e
          @logger.warn("trouble flushing: #{$!}")
          @logger.debug(e.backtrace.join("\n"))
        end
      end # EM.defer
    end # EM.add_periodic_timer
    #EM.stop_event_loop
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

  public
  def carbon_update_str
    updates = []
    now = Time.now.to_i

    timers = {}
    @stats.timers.each do |k, v|
      timers[k] = @stats.timers.delete(k)
    end

    timers.each do |key, values|
      next if values.length == 0
      values.sort!

      # do some basic summarizing of our timer data
      min = values[0]
      max = values[-1]
      mean = min
      maxAtThreshold = min
      if values.length > 1
        threshold_index = ((100 - @opts[:percentile]) / 100.0) \
                  * values.length
        threshold_count = values.length - threshold_index.round
        valid_values = values.slice(0, threshold_count)
        maxAtThreshold = valid_values[-1]
        sum = 0
        valid_values.each { |v| sum += v }
        mean = sum / valid_values.length
      end

      prefix = @opts[:prefix] ? "#{@opts[:prefix]}." : ""
      suffix = @opts[:suffix] ? ".#{@opts[:suffix]}" : ""
      updates << "#{prefix}timers.#{key}.mean#{suffix} #{mean} #{now}"
      updates << "#{prefix}timers.#{key}.upper#{suffix} #{max} #{now}"
      updates << "#{prefix}timers.#{key}.upper_#{@opts[:percentile]}#{suffix} " \
            "#{maxAtThreshold} #{now}"
      updates << "#{prefix}timers.#{key}.lower#{suffix} #{min} #{now}"
      updates << "#{prefix}timers.#{key}.count#{suffix} #{values.length} #{now}"
    end # timers.each

    counters = {}
    @stats.counters.each do |k, v|
      counters[k] = @stats.counters.delete(k)
    end

    # Keep sending a 0 for counters (even if we don't get updates)
    counters.keys.each do |k|
      @stats.counters[k] ||= 0    # Keep sending a 0 if we don't get updates
    end

    counters.each do |key, value|
      prefix = @opts[:prefix] ? "#{@opts[:prefix]}." : ""
      suffix = @opts[:suffix] ? ".#{@opts[:suffix]}" : ""
      updates << "#{prefix}#{key}#{suffix} #{value / @opts[:flush_interval]} #{now}"
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
