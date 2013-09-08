require 'tupelo/app'

N_WORKERS = 3
N_TASKS = 10
N_SLEEPS = 2

Tupelo.application do
  N_WORKERS.times do |w_i|
    child passive: true do
      loop do
        task_id = task_data = nil
        
        transaction do
          _, task_id, task_data = take ["task", nil, nil]
          write ["lease", client_id, task_id, task_data]
          write ["alive", client_id, task_id, (Time.now + 1).to_f]
        end

        N_SLEEPS.times do
          sleep 1 # pretend to be working
          write ["alive", client_id, task_id, (Time.now + 1).to_f]

          # randomly exit or oversleep the lease deadline
          if w_i == 1
            log "bad worker exiting"
            exit
          elsif w_i == 2
            log "bad worker oversleeping"
            sleep 3
          end
        end

        result = task_data * 1000

        begin
          transaction timeout: 0.2 do ## or 0.0 or nowait?
            take ["lease", client_id, task_id, nil]
            write ["result", task_id, result]
              # only write the result if this client still has lease --
              # otherwise, some other client has been assigned to this task.
          end
        rescue TimeoutError
          log.warn "I lost my lease because I didn't finish task in time!"
        end
      end
    end
  end
  
  # lease manager
  child passive: true do
    scheduler = AtDo.new
    alive_until = Hash.new(0)

    loop do
      _, lease_client_id, task_id, time = take ["alive", nil, nil, nil]
      t = alive_until[[lease_client_id, task_id]]
      alive_until[[lease_client_id, task_id]] = [t, time].max

      scheduler.at Time.at(time + 0.2) do # allow for network latency etc.
        t = alive_until[[lease_client_id, task_id]]
        if t and t > Time.now.to_f
          # ok for another period
        else
          task_data = nil
          transaction do
            _,_,_,task_data =
              take_nowait ["lease", lease_client_id, task_id, nil]
              # if lease is gone, ok!
            if task_data
              write ["task", task_id, task_data] # for someone else to work on
            end
          end
          if task_data
            log.warn "took lease from #{lease_client_id} on #{task_id}"
          end
        end
      end
    end
  end
  
  child do
    N_TASKS.times do |task_id|
      task_data = task_id # for simplicity
      write ["task", task_id, task_data]
    end

    N_TASKS.times do |task_id|
      log take ["result", task_id, nil]
    end
    
    extra_results = read_all ["result", nil, nil]
    if extra_results.empty?
      log "results look ok!"
    else
      log.error "extra results = #{extra_results}"
    end
  end
end
