require 'funl/client'
require 'funl/blobber'
require 'funl/message-sequencer'
require 'funl/client-sequencer'
require 'socket'
require 'tmpdir'

include Funl

require 'minitest/autorun'

class TestClient < Minitest::Test
  attr_reader :log, :client

  def setup
    @dir = Dir.mktmpdir "funl-test-client-"
    @cseq_path = File.join(@dir, "cseq")
    @seq_path = File.join(@dir, "seq")
    @log = Logger.new($stderr)
    log.level = Logger::WARN

    @cseq_sock = UNIXServer.new(@cseq_path)
    @cseq = ClientSequencer.new @cseq_sock, log: log
    @cseq.start

    @seq_sock = UNIXServer.new(@seq_path)
    @seq = MessageSequencer.new @seq_sock, log: log
    @seq.start

    @client = Client.new(
      seq: UNIXSocket.new(@seq_path),
      cseq: UNIXSocket.new(@cseq_path),
      log: log)

    @client.start
  end

  def teardown
    cseq.stop rescue nil
    seq.stop rescue nil
    FileUtils.remove_entry @dir
  end

  def test_client_state_at_start
    assert_equal(0, client.client_id)
    assert_equal(0, client.start_tick)
    assert_equal(Funl::Blobber::MSGPACK_TYPE, client.blob_type)
  end

  def test_subscription_tracking
    Thread.new do
      client.subscribe ["foo"]
    end ## Fiber?

    ack = client.seq.read
    assert ack.control?
    assert_equal 0, ack.global_tick

    assert_equal [], client.subscribed_tags
    client.handle_ack ack
    Thread.pass
    assert_equal ["foo"], client.subscribed_tags

    Thread.new do
      client.unsubscribe ["foo"]
    end

    ack = client.seq.read
    assert ack.control?
    assert_equal 0, ack.global_tick

    assert_equal ["foo"], client.subscribed_tags
    client.handle_ack ack
    Thread.pass
    assert_equal [], client.subscribed_tags

    Thread.new do
      client.subscribe_all
    end

    ack = client.seq.read
    assert ack.control?
    assert_equal 0, ack.global_tick

    assert_equal false, client.subscribed_all
    client.handle_ack ack
    Thread.pass
    assert_equal true, client.subscribed_all

    Thread.new do
      client.unsubscribe_all
    end
    ack = client.seq.read
    assert ack.control?
    assert_equal 0, ack.global_tick

    assert_equal true, client.subscribed_all
    client.handle_ack ack
    Thread.pass
    assert_equal false, client.subscribed_all
  end
end
