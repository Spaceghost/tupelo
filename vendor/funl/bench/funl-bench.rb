require 'funl/message-sequencer-select'
require 'funl/message-sequencer-nio'
require 'socket'
require 'tmpdir'

include Funl

class BenchmarkTask
  attr_reader :name, :params

  def initialize name, **params
    @name = name
    @params = params
  end

  def inspect
    ps = params.map{|k,v| "#{k}: #{v}" }
    pstr = ps.empty? ? "" : " " + ps.join(', ')
    "<#{name}#{pstr}>"
  end
end

class WarmupTask < BenchmarkTask
  def run make_stream
    make_stream["1"]
  end
end

# All clients run in the same process; mseq server is in a child process.
class BenchmarkEnv
  attr_reader :name, :dir, :path, :log, :stream_type, :tasks, :mseq_class

  def initialize name, stream_type: ObjectStream::MSGPACK_TYPE,
        mseq_class: MessageSequencer
    @name = name
    @log = Logger.new($stderr)
    log.level = Logger::WARN
    @stream_type = stream_type
    @tasks = []
    @mseq_class = mseq_class
  end

  def add_task task
    @tasks << task
  end
  alias << add_task

  def run
    @dir = Dir.mktmpdir "funl-benchmark-#{name}-"
    @path = File.join(dir, "sock")
    svr = UNIXServer.new(path)
    s0, s1 = UNIXSocket.pair
    @pid = fork do
      run_server svr, s1
    end

    log.progname = "client"

    @mseq_ctrl = ObjectStreamWrapper.new(s0, type: stream_type)

    puts mseq_class
    printf "%6s %6s | %s\n", "client", "server", "task"
    puts "-"*60
    tasks.each do |task|
      run_task task
    end
  ensure
    close
  end

  def run_server svr, s
    log.progname = "#{name}-mseq"
    mseq = mseq_class.new svr, log: log,  stream_type: stream_type
    mseq.start

    run_control_loop(s)
  rescue => ex
    log.error ex
  end

  def run_control_loop s
    t0 = Process.times
    stream = ObjectStreamWrapper.new(s, type: stream_type)
    loop do
      stream.read do |msg|
        case msg
        when "dt"
          t1 = Process.times
          dt = t1.utime + t1.stime - (t0.utime + t0.stime)
          t0 = t1
          stream << dt
        ## when GC start|enable|disable
        else
          raise "unknown control message: #{msg.inspect}"
        end
      end
    end
  end

  def run_task task
    t0 = Process.times
    @mseq_ctrl << "dt"
    task.run method(:make_stream)
    t1 = Process.times
    @mseq_ctrl << "dt"

    @mseq_ctrl.read
    dt = @mseq_ctrl.read

    time = t1.utime + t1.stime - (t0.utime + t0.stime)
    printf "%6.3f %6.3f | %p\n", time, dt, task
  rescue => ex
    log.error "#{task.inspect}: #{ex}"
  end

  def make_stream client_id = nil ## subscriptions?
    conn = UNIXSocket.new(path)
    stream = ObjectStreamWrapper.new(conn, type: stream_type)
    stream.write_to_outbox({"client_id" => client_id})
    stream.write(Message.control(SUBSCRIBE_ALL))
    global_tick = stream.read["tick"]
    stream.expect Message
    ack = stream.read
    stream
  end

  def close
    Process.kill "TERM", @pid if @pid
    Process.waitpid @pid
    FileUtils.remove_entry dir if dir
  end
end
