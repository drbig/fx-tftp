$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'minitest/autorun'
require 'tftpd'

class Packet < Minitest::Test
  def test_parse_rrq
    assert_equal TFTP::Packet.new(:rrq, {:path => 'test.txt', :mode => :netascii}),
                 TFTP::Packet.parse("\x00\x01test.txt\x00netascii\x00")
    assert_equal TFTP::Packet.new(:rrq, {:path => 'binary', :mode => :octet}),
                 TFTP::Packet.parse("\x00\x01binary\x00octet\x00")
    assert_equal TFTP::Packet.new(:rrq, {:path => 'test.txt', :mode => :netascii}),
                 TFTP::Packet.parse("\x00\x01test.txt\x00nEtasCIi\x00")
    assert_equal TFTP::Packet.new(:rrq, {:path => 'binary', :mode => :octet}),
                 TFTP::Packet.parse("\x00\x01binary\x00OCTET\x00")


    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01\x00\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01\x00\x00\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01a\x00c\x00c\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01foo\x00bar\x00") }
  end

  def test_parse_wrq
    assert_equal TFTP::Packet.new(:wrq, {:path => 'test.txt', :mode => :netascii}),
                 TFTP::Packet.parse("\x00\x02test.txt\x00netascii\x00")
    assert_equal TFTP::Packet.new(:wrq, {:path => 'binary', :mode => :octet}),
                 TFTP::Packet.parse("\x00\x02binary\x00octet\x00")
    assert_equal TFTP::Packet.new(:wrq, {:path => 'test.txt', :mode => :netascii}),
                 TFTP::Packet.parse("\x00\x02test.txt\x00NetascIi\x00")
    assert_equal TFTP::Packet.new(:wrq, {:path => 'binary', :mode => :octet}),
                 TFTP::Packet.parse("\x00\x02binary\x00OctEt\x00")


    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x02\x00\x00\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x02a\x00c\x00c\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x02foo\x00bar\x00") }
  end


  def test_parse_data
    assert_equal TFTP::Packet.new(:data, {:seq => 0, :data => "1234"}),
                 TFTP::Packet.parse("\x00\x03\x00\x00\x001234")
    assert_equal TFTP::Packet.new(:data, {:seq => 16, :data => ('a' * 512)}),
                 TFTP::Packet.parse("\x00\x03\x00\x0f" + ('a' * 512))

    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x03\x00\x00") }
  end

  def test_parse_ack
    assert_equal TFTP::Packet.new(:ack, {:seq => 0}),
                 TFTP::Packet.parse("\x00\x04\x00\x00")
    assert_equal TFTP::Packet.new(:ack, {:seq => 65534}),
                 TFTP::Packet.parse("\x00\x04\xfb\xb2")


    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x04\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x04\x00" + ('A' * 8)) }
  end

  def test_parse_error
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x05\x00\xff") }
  end
end
