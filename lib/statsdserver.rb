require "rubygems"
require "eventmachine"
require "logger"
require "socket"
require "timeout"
require "uri"

# Hack because the latest amqp gem uses String#bytesize, and not everyone
# is running ruby 1.8.7.
if !String.instance_methods.include?(:bytesize)
  class String
    alias :bytesize :length
  end
end

class StatsdServer < EventMachine::Connection
  attr_accessor :logger,
                :flush_interval,
                :pct_threshold,
                :key_suffix,
                :key_prefix,
                :outputs

  attr_reader :timers,
              :counters

  public
  def initialize
    @timers = Hash.new { |h, k| h[k] = Array.new }
    @counters = Hash.new { |h, k| h[k] = 0 }
    @logger = Logger.new(STDERR)
    @logger.progname = File.basename($0)
  end # def initialize

  public
  def self.run(opts, outputs)
    opts = {
      :bind => "127.0.0.1",
      :port => 8125,
      :pct_threshold => 90,
      :flush_interval => 30,
    }.merge(opts)

    # argument checking
    [:port, :pct_threshold, :flush_interval].each do |key|
      begin
        opts[key] = Float(opts[key])
      rescue
        raise "#{key}: #{opts[key].inspect}: must be a valid number"
      end
    end

    #EM.run do
      begin
        EM.open_datagram_socket(opts[:bind], opts[:port].to_i,
                                StatsdServer) do |s|
          s.pct_threshold = opts[:pct_threshold]
          s.flush_interval = opts[:flush_interval]
          s.key_prefix = opts[:key_prefix]
          s.key_suffix = opts[:key_suffix]
          s.outputs = outputs

          EM.add_periodic_timer(opts[:flush_interval]) do
            EM.defer do
              begin
                s.flush
              rescue
                s.logger.warn("trouble flushing: #{$!}")
              end
            end # EM.defer
          end # EM.add_periodic_timer
        end # EM.open_datagram_socket
      rescue
        $stderr.puts "Exception inside of EM.run: #{$!}"
        EM.stop_event_loop
        return 1
      end
    #end # EM.run

    return 0
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
        @timers[key] << fields[0].to_f
      elsif fields[1] == "c" # counter update
        count, sample_rate = fields[0].split("@", 2)
        sample_rate ||= 1
        @counters[key] += count.to_f * (1 / sample_rate.to_f)
      else
        @logger.warn("invalid update (#{packet}): unkown type #{fields[1]}")
      end
    end
  end # def receive_data

  public
  def carbon_update_str
    updates = []
    now = Time.now.to_i

    timers = {}
    @timers.each do |k, v|
      timers[k] = @timers.delete(k)
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
        threshold_index = ((100 - @pct_threshold) / 100.0) \
                  * values.length
        threshold_count = values.length - threshold_index.round
        valid_values = values.slice(0, threshold_count)
        maxAtThreshold = valid_values[-1]
        sum = 0
        valid_values.each { |v| sum += v }
        mean = sum / valid_values.length
      end

      suffix = @key_suffix ? ".#{@key_suffix}" : ""
      updates << "stats.timers.#{key}.mean#{suffix} #{mean} #{now}"
      updates << "stats.timers.#{key}.upper#{suffix} #{max} #{now}"
      updates << "stats.timers.#{key}.upper_#{@pct_threshold}#{suffix} " \
            "#{maxAtThreshold} #{now}"
      updates << "stats.timers.#{key}.lower#{suffix} #{min} #{now}"
      updates << "stats.timers.#{key}.count#{suffix} #{values.length} #{now}"
    end # timers.each

    counters = {}
    @counters.each do |k, v|
      counters[k] = @counters.delete(k)
    end
    counters.each do |key, value|
      suffix = @key_suffix ? ".#{@key_suffix}" : ""
      updates << "stats.#{key}#{suffix} #{value / @flush_interval} #{now}"
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
