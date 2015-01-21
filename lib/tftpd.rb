module TFTP
  class Error < Exception; end
  class ParseError < Error; end

  class Protocol
    OPCODES = [:rrq, :wrq, :data, :ack, :error]
    MODES = [:netascii, :octet]

    def tid_get; rand(65535) end

    def opcode_dec(data)
      word = data.force_encoding('ascii-8bit').unpack('n').first
      OPCODES[word - 1]
    end

    def opcode_enc(opcode)
      [OPCODES.index(opcode) + 1].pack('n')
    end
  end

  class Packet
    attr_accessor :opcode, :data

    @@proto = Protocol.new

    def self.parse(data)
      raw = data.force_encoding('ascii-8bit')
      payload = raw.slice(2, raw.length - 2)

      case opcode = @@proto.opcode_dec(raw)
      when :rrq, :wrq
        xs = payload.split("\x00")
        if xs.length != 2
          raise ParseError, "#{xs.length} elements for an #{opcode.to_s.upcase} packet"
        end
        path = xs[0]
        mode = xs[1].downcase.to_sym
        unless Protocol::MODES.member? mode
          raise ParseError, "Unknown mode #{mode}"
        end
        return new(opcode, {:path => path, :mode => mode})
      when :data
        seq = payload.unpack('n')
        data = payload.slice(2, payload.length - 2)
        if data.length > 512 || data.length < 1
          raise ParseError, "Exceeded payload length with #{data.length} bytes"
        end
        return new(opcode, {:seq => seq, :data => data})
      when :ack
        if payload.length != 2
          raise ParseError, "Exceeded payload length with #{payload.length} bytes"
        end
        seq = payload.unpack('n')
        return new(opcode, {:seq => seq})
      else
        raise ParseError, "Unknown opcode '#{raw.slice(0, 2).inspect}'"
      end
    end

    def initialize(opcode, data)
      @opcode = opcode
      @data = data
    end

    def ==(other)
      return false if @opcode != other.opcode
      @data.each_pair {|k,v| return false unless v = other.data[k] }
    end
  end

  class Server
    
  end
end
