require 'funl/message-sequencer'

module Funl
  class MessageSequencerSelect < MessageSequencer
    private

    def init_selector
      @streams = []
    end

    def register_stream stream
      @streams << stream
    end

    def deregister_stream stream
      @streams.delete stream
    end

    def registered_stream? stream
      @streams.include? stream
    end

    def select_streams
      # require 'pry';binding.pry
      readables, _ = select [server, *@streams]

      readables.each do |readable|
        case readable
        when server
          accept_conn
        else
          read_conn readable
        end
      end
    end
  end
end
