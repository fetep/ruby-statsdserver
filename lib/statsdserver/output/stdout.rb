class StatsdServer::Output
  class Stdout
    public
    def initialize(opts = {})
    end

    public
    def send(str)
      puts str
    end
  end # class Stdout
end # class StatsdServer::Output
