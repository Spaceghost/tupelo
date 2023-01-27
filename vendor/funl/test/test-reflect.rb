require 'funl/message-sequencer'
require 'socket'

include Funl

require 'minitest/autorun'

class TestReflect < Minitest::Test
  attr_reader :log, :mseq

  def setup
    @log = Logger.new($stderr)
    log.level = Logger::WARN

    client_socks = []
    server_socks = []
    2.times do
      cl, sv = UNIXSocket.pair
      client_socks << cl
      server_socks << sv
    end

    dummy, _ = UNIXSocket.pair

    @mseq = MessageSequencer.new dummy, *server_socks, log: log
    mseq.start

    @streams = client_socks.each_with_index.map do |s,i|
      stream = ObjectStreamWrapper.new(s, type: mseq.stream_type)
      stream.write_to_outbox({"client_id" => "client #{i}"})
      stream.read["tick"]
      stream.expect Message
      stream
    end
  end

  def teardown
    mseq.stop rescue nil
  end

  def test_reflect
    snd, rcv = @streams
    rcv << Message.control(SUBSCRIBE, ["foo"])
    ack = rcv.read
    assert ack.control?
    assert_equal 0, ack.global_tick
    reflect = true

    snd << Message[
      client: 0, local: 1, global: 0, delta: 1,
      tags: [reflect, "bar"], blob: ""]
    snd << Message[
      client: 0, local: 2, global: 0, delta: 2,
      tags: [reflect, "foo"], blob: ""]

    m = rcv.read
    assert_equal 2, m.global_tick
    assert_equal ["foo"], m.tags

    m = snd.read
    assert_equal 1, m.global_tick
    assert_equal 1, m.local_tick
    assert_equal nil, m.tags
    assert_equal nil, m.blob

    m = snd.read
    assert_equal 2, m.global_tick
    assert_equal 2, m.local_tick
    assert_equal nil, m.tags
    assert_equal nil, m.blob
  end
end
