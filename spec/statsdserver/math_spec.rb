require "rubygems"
require "bundler/setup"

require "rspec/autorun"
require "spec_helper"
require "statsdserver/math"

describe StatsdServer::Math do
  describe ".summarize" do
    it "should calculate min" do
      values = [ 1, 5, 0 ]
      res = StatsdServer::Math.summarize(values)
      res[:min].should eq(0)
    end

    it "should calculate max" do
      values = [ 1, 5, 0 ]
      res = StatsdServer::Math.summarize(values)
      res[:max].should eq(5)
    end

    it "should calculate mean" do
      values = [ 1, 5, 0 ]
      res = StatsdServer::Math.summarize(values)
      res[:mean].should eq(2)
    end

    it "should calculate 90th percentile by default" do
      values = [ 2, 10, 7, 4, 1, 3, 9, 4, 5, 6 ]
      res = StatsdServer::Math.summarize(values)
      res[:max_at_threshold].should eq(9)
    end
  end
end
