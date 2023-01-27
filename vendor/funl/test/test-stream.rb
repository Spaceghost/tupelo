require 'funl/stream'
require 'funl/message'
require 'stringio'
require 'logger'

require 'minitest/autorun'

class TestStream < Minitest::Test
  include Funl::Stream

  attr_reader :client_id
  attr_reader :stream_type
  attr_reader :message_class
  attr_reader :log

  def setup
    # for the Stream mixin:
    @client_id = 42
    @stream_type = ObjectStream::MSGPACK_TYPE
    @message_class = Funl::Message
    @log = Logger.new($stderr)
    log.level = Logger::WARN

    @sio = StringIO.new
  end

  def test_greeting
    client = client_stream_for @sio
    client.write "message"

    @sio.rewind

    server = server_stream_for @sio
    m = server.read

    assert_equal "message", m
    assert_equal "client #{client_id}", server.peer_name
  end

  def test_message_server_stream
    client = client_stream_for @sio
    client.write Funl::Message[client: client_id]

    @sio.rewind

    server = message_server_stream_for @sio
    m = server.read

    assert_kind_of Funl::Message, m
    assert_equal client_id, m.client_id
    assert_equal "client #{client_id}", server.peer_name
  end
end
