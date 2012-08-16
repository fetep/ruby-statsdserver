require "rubygems"
require "rspec"
require "statsdserver/stats"

RSpec.configure do |c|
  c.before(:each) do
    @stats = StatsdServer::Stats.new
  end
end
