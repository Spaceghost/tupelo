module Funl::HistoryWorker
  attr_reader :history

  def initialize client
    super
    @history = client.history_size && Array.new(client.history_size)
      # nil in case of use without UDP
  end

  def record_history msg
    history[global_tick % history.size] = msg if history
  end
end
