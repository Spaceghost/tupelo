module Funl::HistoryClient
  attr_reader :history_size

  # The last N messages are kept.
  HISTORY_SIZE = 1000

  def initialize *args, history_size: HISTORY_SIZE, **opts
    super *args, **opts
    @history_size = history_size
  end
end

