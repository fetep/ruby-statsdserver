class StatsdServer::Output
  class Stdout
    attr_accessor :logger

    public
    def initialize(opts = {})
      @logger = Logger.new(STDERR)
      $stdout.sync = true   # autoflush
    end

    public
    def send(str)
      puts str
    end
  end # class Stdout
end # class StatsdServer::Output
