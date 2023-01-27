require 'funl/message-sequencer'
require 'socket'

include Funl

require 'minitest/autorun'

class TestSubscribe < Minitest::Test
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

  def test_single_tag
    snd, rcv = @streams
    rcv << Message.control(SUBSCRIBE, ["foo"])
    ack = rcv.read
    assert ack.control?
    assert_equal 0, ack.global_tick

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["bar"], blob: ""]
    snd << Message[
      client: 0, local: 0, global: 0, delta: 2,
      tags: ["foo"], blob: ""]

    m = rcv.read
    assert_equal 2, m.global_tick
    assert_equal ["foo"], m.tags
  end

  def test_multiple_tag
    snd, rcv = @streams
    rcv << Message.control(SUBSCRIBE, ["foo", "bar"])
    ack = rcv.read
    assert ack.control?
    assert_equal 0, ack.global_tick
    assert_equal ["foo", "bar"], ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["bar"], blob: ""]
    snd << Message[
      client: 0, local: 0, global: 0, delta: 2,
      tags: ["foo"], blob: ""]

    m = rcv.read
    assert_equal 1, m.global_tick
    assert_equal ["bar"], m.tags
    m = rcv.read
    assert_equal 2, m.global_tick
    assert_equal ["foo"], m.tags
  end

  def test_multiple_receiver
    snd, rcv = @streams; rcv = nil
    @streams.each do |stream|
      stream << Message.control(SUBSCRIBE, ["foo"])
      ack = stream.read
      assert ack.control?
      assert_equal 0, ack.global_tick
      assert_equal ["foo"], ack.control_op[1]
    end

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]

    @streams.each do |stream|
      m = stream.read
      assert_equal 1, m.global_tick
      assert_equal ["foo"], m.tags
    end
  end

  def test_unsubscribe
    snd, rcv = @streams
    rcv << Message.control(SUBSCRIBE, ["foo"])
    ack = rcv.read
    assert ack.control?
    assert_equal 0, ack.global_tick
    assert_equal ["foo"], ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]

    m = rcv.read
    assert_equal 1, m.global_tick
    assert_equal ["foo"], m.tags

    rcv << Message.control(UNSUBSCRIBE, ["foo"])
    ack = rcv.read
    assert ack.control?
    assert_equal 1, ack.global_tick
    assert_equal ["foo"], ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]
    Thread.pass

    rcv << Message.control(SUBSCRIBE, ["foo"])
    ack = rcv.read
    assert ack.control?
    assert_equal 2, ack.global_tick
    assert_equal ["foo"], ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]

    m = rcv.read
    assert_equal 3, m.global_tick
    assert_equal ["foo"], m.tags
  end

  def test_subscribe_all
    snd, rcv = @streams
    rcv << Message.control(SUBSCRIBE_ALL)
    ack = rcv.read
    assert ack.control?
    assert_equal 0, ack.global_tick
    assert_equal nil, ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]

    m = rcv.read
    assert_equal 1, m.global_tick
    assert_equal ["foo"], m.tags

    rcv << Message.control(UNSUBSCRIBE_ALL)
    ack = rcv.read
    assert ack.control?
    assert_equal 1, ack.global_tick
    assert_equal nil, ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]
    Thread.pass

    rcv << Message.control(SUBSCRIBE_ALL)
    ack = rcv.read
    assert ack.control?
    assert_equal 2, ack.global_tick
    assert_equal nil, ack.control_op[1]

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: ""]

    m = rcv.read
    assert_equal 3, m.global_tick
    assert_equal ["foo"], m.tags
  end

  def test_redundant_subscribe
    snd, rcv = @streams
    2.times do
      rcv << Message.control(SUBSCRIBE, ["foo"])
      ack = rcv.read
      assert ack.control?
    end

    snd << Message[
      client: 0, local: 0, global: 0, delta: 1,
      tags: ["foo"], blob: "1"]
    snd << Message[
      client: 0, local: 0, global: 0, delta: 2,
      tags: ["foo"], blob: "2"]

    m = rcv.read
    assert_equal 1, m.global_tick
    assert_equal ["foo"], m.tags
    assert_equal "1", m.blob

    m = rcv.read
    assert_equal 2, m.global_tick
    assert_equal ["foo"], m.tags
    assert_equal "2", m.blob
  end
end
