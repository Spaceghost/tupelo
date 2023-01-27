require_relative 'funl-bench'

# Measure the message rate through the sequencer.
class MessageRateBenchmarkTask < BenchmarkTask
  def run make_stream
    n_msg = params[:n_msg] || 10
    n_cli = params[:n_cli] || 2
    cycle_sender = params[:cycle_sender] || false

    streams = n_cli.times.map {|i| make_stream[i]}
    threads = n_cli.times.map do |i|
      Thread.new do
        n_msg.times do
          streams[i].read
        end
      end
    end

    n_msg.times do |i|
      stream = cycle_sender ? streams[i % n_cli] : streams[0]
      stream <<
        Message[client: "1", local: i, global: nil, delta: nil,
          tags: nil, blob: nil]
    end

    threads.each {|th| th.join}
  end
end

if __FILE__ == $0
  b_sel = BenchmarkEnv.new("msg-rate", mseq_class: MessageSequencerSelect)

  b_sel << WarmupTask.new("warmup")
  b_sel << MessageRateBenchmarkTask.new("msg rate", n_msg: 100, n_cli: 2)
  b_sel << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 2)
  b_sel << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 10)
#  b_sel << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 10,
#    cycle_sender: false)
#  b_sel << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 100)

  b_sel.run

  puts

  b_nio = BenchmarkEnv.new("msg-rate", mseq_class: MessageSequencerNio)

  b_nio << WarmupTask.new("warmup")
  b_nio << MessageRateBenchmarkTask.new("msg rate", n_msg: 100, n_cli: 2)
  b_nio << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 2)
  b_nio << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 10)
#  b_nio << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 10,
#    cycle_sender: false)
#  b_nio << MessageRateBenchmarkTask.new("msg rate", n_msg: 1000, n_cli: 100)

  b_nio.run
end
