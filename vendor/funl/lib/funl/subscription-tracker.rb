require 'thread'
require 'funl/message'

module Funl
  # Threadsafe manager for a client's subscriptions.
  class SubscriptionTracker
    attr_reader :client
    attr_reader :subscribed_all

    def subscribed_tags
      @subscribed_tags.dup
    end

    def initialize client
      @client = client

      @subscribed_tags = []
      @subscribed_all = false

      @waiters = []
      @mon = Monitor.new
      @cvar = @mon.new_cond
    end

    def subscribe tags
      @mon.synchronize do
        if (tags - @subscribed_tags).empty?
          return false
        else
          client.seq << Message.control(SUBSCRIBE, tags)
          wait {(tags - @subscribed_tags).empty?}
          return true
        end
      end
    end

    def subscribe_all
      @mon.synchronize do
        if @subscribed_all
          return false
        else
          client.seq << Message.control(SUBSCRIBE_ALL)
          wait {@subscribed_all}
          return true
        end
      end
    end

    def unsubscribe tags
      @mon.synchronize do
        if (tags & @subscribed_tags).empty?
          return false
        else
          client.seq << Message.control(UNSUBSCRIBE, tags)
          wait {(tags & @subscribed_tags).empty?}
          return true
        end
      end
    end

    def unsubscribe_all
      @mon.synchronize do
        if !@subscribed_all
          return false
        else
          client.seq << Message.control(UNSUBSCRIBE_ALL)
          wait {!@subscribed_all}
          return true
        end
      end
    end

    def update op_type, tags=nil
      @mon.synchronize do
        case op_type
        when SUBSCRIBE;       @subscribed_tags |= tags
        when SUBSCRIBE_ALL;   @subscribed_all = true
        when UNSUBSCRIBE;     @subscribed_tags -= tags
        when UNSUBSCRIBE_ALL; @subscribed_all = false
        else raise ArgumentError
        end

        @cvar.broadcast
      end
    end

    def wait
      until yield
        @cvar.wait ## timeout?
      end
    end
  end
end
