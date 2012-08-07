require "rubygems"
require "rspec"
require "statsdserver/stats"

RSpec.configure do |c|
  c.before(:all) do
  end

  c.before(:each) do
    @stats = StatsdServer::Stats.new
  end

  c.after(:each) do
  end
end
