#!/usr/bin/env ruby

require "rubygems"
require "zmq"

ctx = ZMQ::Context.new(1)
push = ctx.socket(ZMQ::DOWNSTREAM)
puts 'connecting...'
push.connect("tcp://127.0.0.1:8125")
puts 'sending...'
n = 0
loop do
  n += 1
  $stdout.write "#{n} "
  push.send("1;test.counter:1|c")
end
puts 'done.'
