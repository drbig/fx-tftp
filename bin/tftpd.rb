#!/usr/bin/env ruby
#

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'tftpd'
require 'logger'

PORT = ARGV.first.to_i < 1 ? 69 : ARGV.shift.to_i
PATH = ARGV.shift || Dir.pwd
HOST = ARGV.shift

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.formatter = lambda {|s, d, p, m| "#{s.ljust(5)} | #{m}\n" }

begin
  log.info "Serving from and to #{PATH}"
  srv = TFTP::Server::RWSimple.new(PATH, :host => HOST, :port => PORT, :logger => log)
  srv.run!
rescue SignalException => e
  puts if e.is_a? Interrupt
  srv.stop
end

if Thread.list.length > 1
  log.info 'Waiting for outstanding connections'
  Thread.stop
end
