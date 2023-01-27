require 'easy-serve/remote'

tunnel = !!ARGV.delete("--tunnel")
host = ARGV.shift

unless host
  abort <<-END

    Usage: #$0 host [--tunnel]

    The 'host' is the remote address on which client code will run.
    It must be a destination accepted by ssh, optionally including a user name:

      [user@]hostname
    
    The 'hostname' may by any valid hostname or ssh alias.

    If --tunnel is specified, use the ssh connection to tunnel the data
    traffic. Otherwise, just use tcp. (Always use ssh to start the remote
    process.)

  END
end

EasyServe.start do |ez|
  log = ez.log
  log.level = Logger::INFO
  log.formatter = nil if $VERBOSE

  ez.start_services do
    svhost = tunnel ? "localhost" : nil # no need to expose port if tunnelled

    ez.service :seqd, :tcp, bind_host: svhost do |svr|
      require 'funl/message-sequencer'
      seq = Funl::MessageSequencer.new svr, log: log
      seq.start
    end

    ez.service :cseqd, :tcp, bind_host: svhost do |svr|
      require 'funl/client-sequencer'
      cseq = Funl::ClientSequencer.new svr, log: log
      cseq.start
    end
  end

  ez.remote :seqd, :cseqd, host: host, tunnel: tunnel, log: true, eval: %{
    require 'funl/client'

    log.progname = "client (starting) on \#{host}"

    seqd, cseqd = conns
    client = Funl::Client.new(seq: seqd, cseq: cseqd, log: log)
    client.start do
      log.progname = "client #\#{client.client_id} on \#{host}"
    end

    Thread.new do
      client.subscribe_all
    end

    msg = client.seq.read
    raise unless msg.control?
    client.handle_ack msg
    log.info "subscribed"

    msg = Funl::Message[client: client.client_id, blob: "Foo"]
    client.seq << msg
    log.info "sent \#{msg.inspect}:\#{msg.blob.inspect}"
    msg = client.seq.read
    raise if msg.control?
    log.info "received \#{msg.inspect}:\#{msg.blob.inspect}"
  }

  # For comparison, here's a child process on the same host as the services.
  ez.child :seqd, :cseqd do |seqd, cseqd|
    require 'funl/client'

    log.progname = "client (starting) on #{host}"

    client = Funl::Client.new(seq: seqd, cseq: cseqd, log: log)
    client.start do
      log.progname = "client ##{client.client_id} on #{host}"
    end

    Thread.new do
      client.subscribe_all
    end

    msg = client.seq.read
    raise unless msg.control?
    client.handle_ack msg
    log.info "subscribed"

    msg = Funl::Message[client: client.client_id, blob: "Bar"]
    client.seq << msg
    log.info "sent #{msg.inspect}:#{msg.blob.inspect}"
    msg = client.seq.read
    raise if msg.control?
    log.info "received #{msg.inspect}:#{msg.blob.inspect}"
  end
end
