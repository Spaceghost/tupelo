require 'nio'
require 'funl/message-sequencer'

module Funl
  class MessageSequencerNio < MessageSequencer
    private

    def init_selector
      @selector = NIO::Selector.new
      if server
        monitor = @selector.register server, :r
        monitor.value = proc {accept_conn}
      end
    end

    def register_stream stream
      monitor = @selector.register stream, :r
      monitor.value = proc {read_conn stream}
    end

    def deregister_stream stream
      @selector.deregister stream
    end

    def registered_stream? stream
      @selector.registered? stream
    end

    def select_streams
      @selector.select do |monitor|
        monitor.value.call(monitor)
      end
    end
  end
end
