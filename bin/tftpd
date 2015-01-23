#!/usr/bin/env ruby
#

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'logger'
require 'optparse'
require 'tftp'

config = {:path => Dir.pwd, :host => '127.0.0.1', :fork => false,
          :ver => false, :loglevel => Logger::INFO, :logfile => STDOUT}

def die!(msg)
  STDERR.puts msg
  exit(2)
end

op = OptionParser.new do |o|
  o.banner = "Usage: #{$PROGRAM_NAME} [OPTIONS] PORT"
  o.on('-v', '--version', 'Show version and exit')            {    config[:ver]       = true }
  o.on('-d', '--debug', 'Enable debug output')                {    config[:loglevel]  = Logger::DEBUG }
  o.on('-l', '--log PATH',  String, 'Log to file')            {|a| config[:logfile]   = a }
  o.on('-b', '--background', 'Fork into background')          {|a| config[:fork]      = true }
  o.on('-h', '--host HOST', String, 'Bind do host')           {|a| config[:host]      = a }
  o.on('-p', '--path PATH', String, 'Serving root directory') {|a| config[:path]      = a }
end
op.parse! or die!(op)

if config[:ver]
  puts "fx-tftpd v#{TFTP::VERSION} Copyright (c) 2015, Piotr S. Staszewski"
  exit
end

die!('Serving root does not exists') unless File.exists? config[:path]

PORT = ARGV.shift.to_i
die!(op) if PORT < 1 || PORT > 65535

log = Logger.new(config[:logfile])
log.level = config[:loglevel]
log.formatter = lambda {|s, d, p, m| "#{d.strftime('%Y-%m-%d %H:%M:%S.%3N')} | #{s.ljust(5)} | #{m}\n" }

if config[:fork]
  log.info 'Detaching from the console'
  Process.daemon(true)
end

begin
  log.info "Serving from and to #{config[:path]}"
  srv = TFTP::Server::RWSimple.new(config[:path], :host => config[:host], :port => PORT, :logger => log)
  srv.run!
rescue SignalException => e
  puts if e.is_a? Interrupt
  srv.stop
end

if Thread.list.length > 1
  log.info 'Waiting for outstanding connections'
  Thread.stop
end
