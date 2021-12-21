require 'iknow_cache'

require 'minitest/autorun'

# Work around rails 7 bug
# https://github.com/rails/rails/issues/43851
begin
  require "active_support/isolated_execution_state"
rescue LoadError => _e
  # This file isn't present for older rails versions, so ignore errors
  # trying to load it.
  nil
end

require 'active_support/logger'
require 'active_support/cache'

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

IknowCache.configure! do
  logger ActiveSupport::Logger.new(STDOUT)
  cache ActiveSupport::Cache::MemoryStore.new
end
