require 'funl/message'
require 'socket'
require 'stringio'
require 'msgpack'

require 'minitest/autorun'

class TestMessage < Minitest::Test
  attr_reader :m, :sio

  def setup
    @m = Funl::Message.new
    m.client_id = 12
    m.local_tick = 34
    m.global_tick = 56
    m.delta = 78
    m.tags = [ "aaa", "bbb" ]
    m.blob = "BLOB"
  end

  def test_from_serialized
    a = m.to_a
    m2 = Funl::Message.from_serialized a
    assert_equal(m, m2)
  end

  def test_to_msgpack
    assert_kind_of(String, m.to_msgpack(nil))
    assert_kind_of(String, m.to_msgpack)
    assert_equal(MessagePack.pack(m), m.to_msgpack(nil))
    assert_equal(MessagePack.pack(m), m.to_msgpack)
  end

  def test_to_msgpack_packer
    pk = MessagePack::Packer.new
    assert_kind_of(MessagePack::Packer, m.to_msgpack(pk))
    assert_equal(pk, m.to_msgpack(pk))
  end

  def test_to_msgpack_io
    src, dst = UNIXSocket.pair
    assert_nil(m.to_msgpack(src))
    src.close
    assert_equal(MessagePack.pack(m), dst.read)
  end

  def test_pack_io
    src, dst = UNIXSocket.pair
    MessagePack.pack(m, src)
    src.close
    assert_equal(MessagePack.pack(m), dst.read)
  end

  def test_pack_unpack
    assert_equal(m.to_a, MessagePack.unpack(MessagePack.pack(m)))
  end

  def test_from_msgpack_str
    assert_equal(m, Funl::Message.from_msgpack(MessagePack.pack(m)))
  end

  def test_from_msgpack_stringio
    sio = StringIO.new
    MessagePack.pack(m, sio)
    sio.rewind
    assert_equal(m, Funl::Message.from_msgpack(sio))
  end

  def test_from_msgpack_io
    src, dst = UNIXSocket.pair
    MessagePack.pack(m, src)
    src.close
    assert_equal(m, Funl::Message.from_msgpack(dst))
  end
end
