#!/usr/bin/env ruby
# ruby examples/echochat.rb

$: << File.expand_path('../../lib/', __FILE__)
require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :sockets, []

$sum = 0

Thread.new do # trivial example work thread
  while true do
    sleep 1
    $sum += 1
    EM.next_tick { settings.sockets.each{|s| s.send("Sum: #{$sum}") } }
  end
end

get '/' do
  return erb :index unless request.websocket?

  request.websocket do |ws|
    ws.onopen do
      settings.sockets << ws
    end
    ws.onmessage do |msg|
      EM.next_tick { settings.sockets.each{|s| s.send(msg+$sum.to_s) } }
    end
    ws.onclose do
      settings.sockets.delete(ws)
    end
  end
end
