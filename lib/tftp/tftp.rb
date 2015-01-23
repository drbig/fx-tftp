# After https://www.ietf.org/rfc/rfc1350.txt
#

require 'socket'

module TFTP
  class Error < Exception; end
  class ParseError < Error; end

  module Packet
    class Base < Struct
      def encode; to_str.force_encoding('ascii-8bit'); end
    end

    RRQ = Base.new(:filename, :mode)
    class RRQ
      def to_str; "\x00\x01" + self.filename + "\x00" + self.mode.to_s + "\x00"; end
    end

    WRQ = Base.new(:filename, :mode)
    class WRQ
      def to_str; "\x00\x02" + self.filename + "\x00" + self.mode.to_s + "\x00"; end
    end

    DATA = Base.new(:seq, :data)
    class DATA
      def to_str; "\x00\x03" + [self.seq].pack('n') + self.data; end
      def last?; self.data.length < 512; end
    end

    ACK = Base.new(:seq)
    class ACK
      def to_str; "\x00\x04" + [self.seq].pack('n'); end
    end

    ERROR = Base.new(:code, :msg)
    class ERROR
      def to_str; "\x00\x05" + [self.code].pack('n') + self.msg + "\x00"; end
    end

    def self.parse(data)
      data = data.force_encoding('ascii-8bit')

      opcode = data.unpack('n').first
      if opcode < 1 || opcode > 5
        raise ParseError, "Unknown packet opcode '#{opcode.inspect}'"
      end

      payload = data.slice(2, data.length - 2)
      case opcode
      when 1, 2 # rrq, wrq
        raise ParseError, 'Not null terminated' if payload.slice(payload.length - 1) != "\x00"
        xs = payload.split("\x00")
        raise ParseError, "Not enough elements: #{xs.inspect}" if xs.length < 2
        filename = xs[0]
        mode = xs[1].downcase.to_sym
        raise ParseError, "Unknown mode '#{xs[1].inspect}'" unless [:netascii, :octet].member? mode
        return RRQ.new(filename, mode) if opcode == 1
        return WRQ.new(filename, mode)
      when 3 # data
        seq = payload.unpack('n').first
        block = payload.slice(2, payload.length - 2) || ''
        raise ParseError, "Exceeded block length with #{block.length} bytes" if block.length > 512
        return DATA.new(seq, block)
      when 4 # ack
        raise ParseError, "Wrong payload length with #{payload.length} bytes" if payload.length != 2
        seq = payload.unpack('n').first
        return ACK.new(seq)
      when 5 # error
        raise ParseError, 'Not null terminated' if payload.slice(payload.length - 1) != "\x00"
        code = payload.unpack('n').first
        raise ParseError, "Unknown error code '#{code.inspect}'" if code < 0 || code > 7
        msg = payload.slice(2, payload.length - 3) || ''
        return ERROR.new(code, msg)
      end
    end
  end

  module Handler
    class Base
      def initialize(opts = {})
        @logger = opts[:logger]
        @timeout = opts[:timeout] || 5
        @opts = opts
      end

      def send(tag, sock, io)
        seq = 1
        begin
          while not io.eof?
            block = io.read(512)
            sock.send(Packet::DATA.new(seq, block).encode, 0)
            unless IO.select([sock], nil, nil, @timeout)
              log :warn, "#{tag} Timeout at block ##{seq}"
              return
            end
            msg, _ = sock.recvfrom(4, 0)
            pkt = Packet.parse(msg)
            if pkt.class != Packet::ACK
              log :warn, "#{tag} Expected ACK but got: #{pkt.class}"
              return
            end
            if pkt.seq != seq
              log :warn, "#{tag} Seq mismatch: #{seq} != #{pkt.seq}"
              return
            end
            seq += 1
          end
        rescue ParseError => e
          log :warn, "#{tag} Packet parse error: #{e.to_s}"
          return
        end
        log :info, "#{tag} Sent file"
      end

      def recv(tag, sock, io)
        sock.send(Packet::ACK.new(0).encode, 0)
        seq = 1
        begin
          loop do
            unless IO.select([sock], nil, nil, @timeout)
              log :warn, "#{tag} Timeout at block ##{seq}"
              return false
            end
            msg, _ = sock.recvfrom(516, 0)
            pkt = Packet.parse(msg)
            if pkt.class != Packet::DATA
              log :warn, "#{tag} Expected DATA but got: #{pkt.class}"
              return false
            end
            if pkt.seq != seq
              log :warn, "#{tag} Seq mismatch: #{seq} != #{pkt.seq}"
              return false
            end
            io.write(pkt.data)
            sock.send(Packet::ACK.new(seq).encode, 0)
            break if pkt.last?
            seq += 1
          end
        rescue ParseError => e
          log :warn, "#{tag} Packet parse error: #{e.to_s}"
          return false
        end
        log :info, "#{tag} Received file"
        true
      end

      private
      def log(level, msg)
        @logger.send(level, msg) if @logger
      end
    end

    class RWSimple < Base
      def initialize(path, opts = {})
        @path = path
        super(opts)
      end

      def run!(tag, req, sock, src)
        name = req.filename.gsub('..', '__')
        path = File.join(@path, name)

        case req
        when Packet::RRQ
          log :info, "#{tag} Read request for #{req.filename} (#{req.mode})"
          unless File.exist? path
            log :warn, "#{tag} File not found"
            sock.send(Packet::ERROR.new(1, 'File not found.').encode, 0)
            sock.close
            return
          end
          mode = 'r'
          mode += 'b' if req.mode == :octet
          io = File.open(path, mode)
          send(tag, sock, io)
          sock.close
          io.close
        when Packet::WRQ
          log :info, "#{tag} Write request for #{req.filename} (#{req.mode})"
          if File.exist? path
            log :warn, "#{tag} File already exist"
            sock.send(Packet::ERROR.new(6, 'File already exists.').encode, 0)
            sock.close
            return
          end
          mode = 'w'
          mode += 'b' if req.mode == :octet
          io = File.open(path, mode)
          ok = recv(tag, sock, io)
          sock.close
          io.close
          unless ok
            log :warn, "#{tag} Removing partial file #{req.filename}"
            File.delete(path)
          end
        end
      end
    end
  end

  module Server
    class Base
      attr_reader :handler, :host, :port, :clients

      def initialize(handler, opts = {})
        @handler = handler

        @host = opts[:host] || '0.0.0.0'
        @port = opts[:port] || 69
        @logger = opts[:logger]

        @clients = Hash.new
        @run = false
      end

      def run!
        log :info, "UDP server loop at #{@host}:#{@port}"
        @run = true
        Socket.udp_server_loop(@host, @port) do |msg, src|
          break unless @run

          addr = src.remote_address
          tag = "[#{addr.ip_address}:#{addr.ip_port.to_s.ljust(5)}]"
          log :info, "#{tag} New initial packet received"

          begin
            pkt = Packet.parse(msg)
          rescue ParseError => e
            log :warn, "#{tag} Packet parse error: #{e.to_s}"
            next
          end

          log :debug, "#{tag} -> PKT: #{pkt.inspect}"
          tid = get_tid
          tag = "[#{addr.ip_address}:#{addr.ip_port.to_s.ljust(5)}:#{tid.to_s.ljust(5)}]"
          sock = addr.connect_from(@host, tid)
          @clients[tid] = tag

          unless pkt.is_a?(Packet::RRQ) || pkt.is_a?(Packet::WRQ)
            log :warn, "#{tag} Bad initial packet: #{pkt.class}"
            sock.send(Packet::ERROR.new(4, 'Illegal TFTP operation.').encode, 0)
            sock.close
            next
          end

          Thread.new do
            @handler.run!(tag, pkt, sock, src)
            @clients.delete(tid)
            log :info, "#{tag} Session ended"
          end
        end
        log :info, 'UDP server loop has stopped'
      end

      def stop
        log :info, 'Stopping UDP server loop'
        @run = false
        UDPSocket.new.send('break', 0, @host, @port)
      end

      private
      def get_tid
        tid = 1024 + rand(64512)
        tid = 1024 + rand(64512) while @clients.has_key? tid
        tid
      end

      def log(level, msg)
        @logger.send(level, msg) if @logger
      end
    end

    class RWSimple < Base
      def initialize(path, opts = {})
        handler = Handler::RWSimple.new(path, opts)
        super(handler, opts)
      end
    end
  end
end
