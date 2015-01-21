# After https://www.ietf.org/rfc/rfc1350.txt
#

module TFTP
  class Error < Exception; end
  class ParseError < Error; end

  class Protocol
    OPCODES = [:rrq, :wrq, :data, :ack, :error]
    MODES = [:netascii, :octet]
    ERRORS = [:undef, :not_found, :access_denied, :disk_full, :illegal, :wrong_uid, :file_exists, :unk_user]
    ERRORS_SIZE = ERRORS.length - 1

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
        if payload.slice(payload.length - 1) != "\x00"
          raise ParseError, 'Not null terminated'
        end
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
        seq = payload.unpack('n').first
        data = payload.slice(2, payload.length - 2)
        if data.length > 512 || data.length < 1
          raise ParseError, "Exceeded payload length with #{data.length} bytes"
        end
        return new(opcode, {:seq => seq, :data => data})
      when :ack
        if payload.length != 2
          raise ParseError, "Exceeded payload length with #{payload.length} bytes"
        end
        seq = payload.unpack('n').first
        return new(opcode, {:seq => seq})
      when :error
        if payload.slice(payload.length - 1) != "\x00"
          raise ParseError, 'Not null terminated'
        end
        code = payload.unpack('n').first
        if code < 0 || code > Protocol::ERRORS_SIZE
          rase ParseError, "Unknown error code #{code.isnpect}"
        end
        msg = payload.slice(2, payload.length - 3)
        return new(opcode, {:code => code, :msg => msg})
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
