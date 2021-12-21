# frozen_string_literal: true

class IknowCache
  class Railtie < Rails::Railtie
    config.after_initialize do
      unless IknowCache.configured?
        IknowCache.configure! do
          logger Rails.logger
          cache Rails.cache
        end
      end
    end
  end
end
