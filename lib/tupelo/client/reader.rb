require 'tupelo/client/common'

class Tupelo::Client
  # include into class that defines #worker and #log
  module Api
    ## need read with more complex predicates: |, &, etc
    def read_wait template
      waiter = Waiter.new(worker.make_template(template), self)
      worker << waiter
      result = waiter.wait
      waiter = nil
      result
    ensure
      worker << Unwaiter.new(waiter) if waiter
    end
    alias read read_wait

    ## need nonwaiting reader that accepts 2 or more templates
    def read_nowait template
      matcher = Matcher.new(worker.make_template(template), self)
      worker << matcher
      matcher.wait
    end

    # By default, reads *everything*.
    def read_all template = Object
      matcher = Matcher.new(worker.make_template(template), self, :all => true)
      worker << matcher
      a = []
      while tuple = matcher.wait ## inefficient?
        yield tuple if block_given?
        a << tuple
      end
      a
    end

    def notifier
      NotifyWaiter.new(self).tap {|n| n.toggle}
    end
  end

  class WaiterBase
    attr_reader :template
    attr_reader :queue

    def initialize template, client
      @template = template
      @queue = client.make_queue
    end

    def gloms tuple
      if template === tuple
        peek tuple
        true
      else
        false
      end
    end
    
    def peek tuple
      queue << tuple
    end

    def wait
      queue.pop
    end

    def inspect
      "<#{self.class}: #{template.inspect}>"
    end
  end
  
  class Waiter < WaiterBase
  end
  
  class Matcher < WaiterBase
    attr_reader :all # this is only cosmetic -- see #inspect

    def initialize template, client, all: false
      super template, client
      @all = all
    end

    def fails
      queue << nil
    end

    def inspect
      e = all ? "all " : ""
      t = template.inspect
      "<#{self.class}: #{e}#{t}>"
    end
  end

  # Instrumentation.
  class NotifyWaiter
    attr_reader :queue

    def initialize client
      @client = client
      @queue = client.make_queue
    end

    def << event
      queue << event
    end

    def wait
      queue.pop
    end

    def toggle
      @client.worker << self
    end

    def inspect
      to_s
    end
  end
end
