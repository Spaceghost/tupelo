module Funl
  class Message
    # Unique (per funl instance) sequential id of client who sent message.
    attr_accessor :client_id

    # Client's sequential id of message, unique only in client scope.
    attr_accessor :local_tick

    # Global sequential id of message, unique in scope of funl instance.
    # In client request to funl, this means last ack-ed global tick.
    # Assummed to be 64 bits, to avoid rollover errors.
    attr_accessor :global_tick

    # In client request, how far ahead of ack this message is. When
    # messages are pipelined, delta > 1.
    attr_accessor :delta

    # Application-defined metadata. May be used for filtering etc. Must be an
    # array or nil. If mseq detects +true+ among the tags, then mseq _reflects_
    # the message: it sends the message back to the sender (minus tags and blob,
    # and with updated global_tick). This is so that a client can send mseq a
    # message with tags it does not subscribe to and know when it has arrived.
    # The +true+ is removed from the tag list before mseq sends it to
    # subscribers.
    attr_accessor :tags

    # Application-defined payload data. See blobber.rb.
    attr_accessor :blob

    def initialize(*args)
      @client_id, @local_tick, @global_tick, @delta, @tags, @blob = *args
    end

    def self.[](
      client: nil, local: nil, global: nil, delta: nil, tags: nil, blob: nil)
      new client, local, global, delta, tags, blob
    end

    def self.control op_type, *args
      Message.new.tap {|m| m.client_id = [op_type, *args]}
    end

    # Is this a control packet rather than a data packet?
    def control?
      @client_id.kind_of? Array
    end

    # Array of [op_type, *args] for the control operation.
    def control_op
      @client_id
    end

    def inspect
      d = delta ? "+#{delta}" : nil
      t = tags ? " #{tags}" : nil
      s = [
        "client #{client_id}",
        "local #{local_tick}",
        "global #{global_tick}#{d}"
      ].join(", ")
      "<Message: #{s}#{t}>"
    end

    def to_a
      [@client_id, @local_tick, @global_tick, @delta, @tags, @blob]
    end

    def == other
      other.kind_of? Message and
        @client_id = other.client_id and
        @local_tick = other.local_tick and
        @global_tick = other.global_tick and
        @delta = other.delta and
        @tags = other.tags and
        @blob = other.blob
    end
    alias eql? ==

    def hash
      @client_id.hash ^ @local_tick.hash ^ @global_tick.hash
    end

    # Call with Packer, nil, or IO. If +pk+ is nil, returns string. If +pk+ is
    # a Packer, returns the Packer, which will need to be flushed. If +pk+ is
    # IO, returns nil.
    def to_msgpack(pk = nil)
      case pk
      when MessagePack::Packer
        pk.write_array_header(6)
        pk.write @client_id
        pk.write @local_tick
        pk.write @global_tick
        pk.write @delta
        pk.write @tags
        pk.write @blob
        return pk

      else # nil or IO
        MessagePack.pack(self, pk)
      end
    end

    def to_json
      to_a.to_json
    end

    def self.from_serialized ary
      new(*ary)
    end

    def self.from_msgpack(src)
      case src
      when MessagePack::Unpacker
        new(*src.read)

      when IO, StringIO
        from_msgpack(MessagePack::Unpacker.new(src))

      else # String
        from_msgpack(MessagePack::Unpacker.new.feed(src))
      end
    end
  end
end
