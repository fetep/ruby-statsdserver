class StatsdServer
  class Stats
    attr_accessor :counters,
                  :timers,
                  :logger

    public
    def initialize
      @timers = Hash.new { |h, k| h[k] = Array.new }
      @counters = Hash.new { |h, k| h[k] = 0 }
      @logger = Logger.new(STDERR)
    end
  end # class Stats
end # class StatsdServer
