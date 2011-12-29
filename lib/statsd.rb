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

module StatsD
  @@timers = Hash.new { |h, k| h[k] = Array.new }
  @@timers_mutex = Mutex.new
  @@counters = Hash.new { |h, k| h[k] = 0 }
  @@counters_mutex = Mutex.new
  @@logger = Logger.new(STDERR)
  @@logger.progname = File.basename($0)
  @@flush_interval = 10
  @@pct_threshold = 90
  @@output_func = :output_stdout
  @@key_suffix = nil

  def self.logger; return @@logger; end
  def self.logger_output=(output)
    @@logger = Logger.new(output)
    @@logger.progname = File.basename($0)
  end

  def self.flush_interval=(val)
    @@flush_interval = val.to_i
  end

  def self.pct_threshold=(val)
    @@pct_threshold = val.to_i
  end

  def self.key_suffix=(val)
    @@key_suffix = val
  end

  def self.output_url=(url)
    @@output_url = URI.parse(url)
    scheme_mapper = {"tcp" => [nil, :output_tcp],
                     "amqp" => [:setup_amqp, :output_amqp],
                     "stdout" => [nil, :output_stdout],
                     }
    if ! scheme_mapper.has_key?(@@output_url.scheme)
      raise TypeError, "unsupported scheme in #{url}"
    end

    setup_func, @@output_func = scheme_mapper[@@output_url.scheme]
    self.send(setup_func) if setup_func
  end

  # TODO: option for persistent tcp connection
  #def setup_tcp
  #end

  def self.output_tcp(packet)
    server = TCPSocket.new(@@output_url.host, @@output_url.port)
    server.puts packet
    server.close
  end

  def self.setup_amqp
    begin
      require "amqp"
      require "mq"
    rescue LoadError
      @@logger.fatal("missing amqp ruby module. try gem install amqp")
      exit(1)
    end

    user = @@output_url.user || ""
    user, vhost = user.split("@", 2)
    _, mqtype, mqname = @@output_url.path.split("/", 3)
    amqp_settings = {
      :host => @@output_url.host,
      :port => @@output_url.port || 5672,
      :user => user,
      :pass => @@output_url.password,
      :vhost => vhost || "/",
    }

    @amqp = AMQP.connect(amqp_settings)
    @mq = MQ.new(@amqp)
    @target = nil
    opts = {:durable => true,
            :auto_delete => false,
           }
 
    if @@output_url.query
      @@output_url.query.split("&").each do |param|
        k, v = param.split("=", 2)
        opts[:durable] = false if k == "durable" and v == "false"
        opts[:auto_delete] = true if k == "autodelete" and v == "true"
      end
    end

    @@logger.info(opts.inspect)

    case mqtype
      when "fanout"
        @target = @mq.fanout(mqname, opts)
      when "queue"
        @target = @mq.queue(mqname, opts)
      when "topic"
        @target = @mq.topic(mqname, opts)
      else
        raise TypeError, "unknown mq output type #{mqname}"
    end
  end

  def self.output_amqp(packet)
    @target.publish(packet)
  end

  def self.output_stdout(packet)
    $stdout.write(packet)
  end

  def receive_data(packet)
    bits = packet.strip.split(":")
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
        @@timers_mutex.synchronize do
          @@timers[key] << fields[0].to_f
        end
      elsif fields[1] == "c" # counter update
        count, sample_rate = fields[0].split("@", 2)
        sample_rate ||= 1
        #puts "count is #{count.to_f} (#{count})"
        #puts "multiplier is is #{1 / sample_rate.to_f}"
        @@counters_mutex.synchronize do
          @@counters[key] += count.to_f * (1 / sample_rate.to_f)
        end
      else
        $stderr.puts "invalid field in update: #{bit}"
      end
    end
  end

  def self.carbon_update_str
    updates = []
    now = Time.now.to_i

    @@timers_mutex.synchronize do
      @@timers.each do |key, values|
        next if values.length == 0
        values.sort!
        min = values[0]
        max = values[-1]
        mean = min
        maxAtThreshold = min
        if values.length > 1
          threshold_index = ((100 - @@pct_threshold) / 100.0) * values.length
          threshold_count = values.length - threshold_index.round
          valid_values = values.slice(0, threshold_count)
          maxAtThreshold = valid_values[-1]

          sum = 0
          valid_values.each { |v| sum += v }
          mean = sum / valid_values.length
        end

        suffix = @@key_suffix ? ".#{@@key_suffix}" : ""
        updates << "stats.timers.#{key}.mean#{suffix} #{mean} #{now}"
        updates << "stats.timers.#{key}.upper#{suffix} #{max} #{now}"
        updates << "stats.timers.#{key}.upper_#{@@pct_threshold}#{suffix} " \
                  "#{maxAtThreshold} #{now}"
        updates << "stats.timers.#{key}.lower#{suffix} #{min} #{now}"
        updates << "stats.timers.#{key}.count#{suffix} #{values.length} #{now}"
      end

      @@timers.each { |k, v| @@timers[k] = [] }
    end

    @@counters_mutex.synchronize do
      @@counters.each do |key, value|
        suffix = @@key_suffix ? ".#{@@key_suffix}" : ""
        updates << "stats.#{key}#{suffix} #{value / @@flush_interval} #{now}"
      end

      @@counters.each { |k, v| @@counters[k] = 0 }
    end

    return updates.length == 0 ? nil : updates.join("\n") + "\n"
  end

  def self.flush
    s = carbon_update_str
    return unless s

    begin
      Timeout::timeout(2) { self.send(@@output_func, s) }
    rescue Timeout::Error
      @@logger.warn("timed out sending update to #{@@output_url}")
    rescue
      @@logger.warn("error sending update to #{@@output_url}: #{$!}")
    end
  end
end
