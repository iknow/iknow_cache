require 'iknow_cache'

require 'minitest/autorun'
require 'minitest/ci'

require 'active_support'
require 'active_support/logger'
require 'active_support/cache'

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

IknowCache.configure! do
  logger ActiveSupport::Logger.new(STDOUT)
  cache ActiveSupport::Cache::MemoryStore.new
end
