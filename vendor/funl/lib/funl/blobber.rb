require 'object-stream'

module Funl
  module Blobber
    MARSHAL_TYPE  = ObjectStream::MARSHAL_TYPE
    YAML_TYPE     = ObjectStream::YAML_TYPE
    JSON_TYPE     = ObjectStream::JSON_TYPE
    MSGPACK_TYPE  = ObjectStream::MSGPACK_TYPE

    module JSON_SYM
      def self.load arg
        JSON.parse arg, symbolize_keys: true
      end

      def self.dump arg
        JSON.dump arg
      end
    end

    module MessagePack_SYM
      def self.load arg
        MessagePack.load arg, symbolize_keys: true
      end

      def self.dump arg
        MessagePack.dump arg
      end
    end

    # Returns something which responds to #dump(obj) and #load(str).
    def self.for type, symbolize_keys: false
      case type
      when MARSHAL_TYPE
        Marshal

      when YAML_TYPE
        require 'yaml'
        YAML

      when JSON_TYPE
        require 'yajl'
        require 'yajl/json_gem'
        ## would 'json' conflict with yajl required from other libs?
        if symbolize_keys
          JSON_SYM
        else
          JSON
        end

      when MSGPACK_TYPE
        require 'msgpack'
        if symbolize_keys
          MessagePack_SYM
        else
          MessagePack
        end

      else
        raise ArgumentError, "unknown type: #{type.inspect}"
      end
    end
  end
end
