$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'minitest/autorun'
require 'tftpd'

class Protocol < Minitest::Test
  def setup
    @p = TFTP::Protocol.new
  end

  def test_opcode_dec
    assert_equal :rrq,    @p.opcode_dec("\x00\x01givver")
    assert_equal :wrq,    @p.opcode_dec("\x00\x02javver")
    assert_equal :data,   @p.opcode_dec("\x00\x03almost")
    assert_equal :ack,    @p.opcode_dec("\x00\x04whatever")
    assert_equal :error,  @p.opcode_dec("\x00\x05youlike")
  end

  def test_opcode_enc
    assert_equal "\x00\x01", @p.opcode_enc(:rrq)
    assert_equal "\x00\x02", @p.opcode_enc(:wrq)
    assert_equal "\x00\x03", @p.opcode_enc(:data)
    assert_equal "\x00\x04", @p.opcode_enc(:ack)
    assert_equal "\x00\x05", @p.opcode_enc(:error)
  end
end
