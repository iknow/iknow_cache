# encoding: UTF-8

class IknowCache
  def self.register_group(name, key_name, default_options: nil, static_version: nil)
    group = CacheGroup.new(nil, name, key_name, default_options, static_version)
    yield group if block_given?
    group
  end

  class CacheGroup
    attr_reader :parent, :default_options, :name, :key_name, :key

    def initialize(parent, name, key_name, default_options, static_version)
      @parent          = parent
      @name            = name
      @key_name        = key_name
      @key             = Struct.new(*parent.try { |p| p.key.members }, key_name)
      @default_options = IknowCache::merge_options(parent&.default_options, default_options).try { |x| x.dup.freeze }
      @static_version   = static_version

      @caches          = []
      @children        = []
    end

    def register_child_group(name, key_name, default_options: nil, static_version: nil)
      group = CacheGroup.new(self, name, key_name, default_options, static_version)
      @children << group
      yield group if block_given?
      group
    end

    def register_cache(name, cache_options: nil)
      c = Cache.new(self, name, cache_options)
      @caches << c
      c
    end

    # Clear this key in all Caches in this CacheGroup.
    # It is an error to do this if this CacheGroup has an statically versioned child, as that child cannot be invalidated.
    def delete_all(key, parent_path: nil)
      @caches.each do |cache|
        cache.delete(key, parent_path: parent_path)
      end

      @children.each do |child_group|
        child_group.invalidate_cache_group(key)
      end
    end

    # Clear all keys in this cache group (for the given parent),
    # invalidating all caches in it and its children
    def invalidate_cache_group(parent_key = nil)
      if @static_version.nil?
        parent_path = self.parent_path(parent_key)
        Rails.cache.increment(version_path_string(parent_path))
      else
        raise ArgumentError.new("Cannot invalidate statically versioned cache group")
      end
    end

    # Fetch the path for this cache. We allow the parent_path to be precomputed
    # to save hitting the cache multiple times for its version.
    def path(key, parent_path = nil)
      if key.nil? || !key.has_key?(self.key_name)
        raise ArgumentError.new("Missing required key '#{self.key_name}' for cache '#{self.name}'")
      end
      key_value     = key[self.key_name]
      parent_path ||= self.parent_path(key)
      version       = self.version(parent_path)
      path_string(parent_path, version, key_value)
    end

    ROOT_PATH = "IknowCache".freeze

    def parent_path(parent_key = nil)
      if parent.nil?
        ROOT_PATH
      else
        parent.path(parent_key)
      end
    end

    def version(parent_path)
      if @static_version.nil?
        Rails.cache.fetch(version_path_string(parent_path), raw: true) { 1 }
      else
        @static_version
      end
    end

    # compute multiple paths at once: returns { key => path }
    def path_multi(keys)
      # compute parent path for each key
      parent_paths = self.parent_path_multi(keys)

      # and versions for each parent path
      versions = self.version_multi(parent_paths.values.uniq)

      # update parent_paths with our paths
      keys.each do |key|
        parent_path = parent_paths[key]
        version     = versions[parent_path]
        key_value   = key[self.key_name] or raise ArgumentError.new("Required cache key missing: #{self.key_name}")

        parent_paths[key] = path_string(parent_path, version, key_value)
      end

      parent_paths
    end

    # look up multiple parent paths at once, returns { key => parent_path }
    def parent_path_multi(parent_keys = nil)
      if parent.nil?
        parent_keys.each_with_object({}) { |k, h| h[k] = ROOT_PATH }
      else
        parent.path_multi(parent_keys)
      end
    end

    # Look up multiple versions at once, returns { parent_path => version }
    def version_multi(parent_paths)
      if @static_version.nil?
        # compute version paths
        version_by_pp = parent_paths.each_with_object({}) { |pp, h| h[pp] = version_path_string(pp) }
        version_paths = version_by_pp.values

        # look up versions in cache
        versions = Rails.cache.read_multi(*version_paths, raw: true)

        version_paths.each do |vp|
          next if versions.has_key?(vp)
          versions[vp] = Rails.cache.fetch(vp, raw: true) { 1 }
        end

        # swap in the versions
        parent_paths.each do |pp|
          vp = version_by_pp[pp]
          version = versions[vp]
          version_by_pp[pp] = version
        end

        version_by_pp
      else
        Hash.new(@static_version)
      end
    end

    private

    def path_string(parent_path, version, value)
      "#{parent_path}/#{name}/#{version}/#{value}"
    end

    def version_path_string(parent_path)
      "#{parent_path}/#{name}/_version"
    end
  end

  class Cache
    DEBUG = false

    attr_reader :name, :cache_options, :cache_group

    def initialize(cache_group, name, cache_options)
      @cache_group   = cache_group
      @name          = name
      @cache_options = IknowCache::merge_options(cache_group.default_options, cache_options).try { |x| x.dup.freeze }
    end

    def fetch(key, parent_path: nil, **options, &block)
      p = path(key, parent_path)
      Rails.logger.debug("Cache Fetch: #{p}") if DEBUG
      v = Rails.cache.fetch(p, IknowCache::merge_options(cache_options, options), &block)
      Rails.logger.debug("=> #{v.inspect}") if DEBUG
      v
    end

    def read(key, parent_path: nil, **options)
      p = path(key, parent_path)
      Rails.logger.debug("Cache Read: #{p}") if DEBUG
      v = Rails.cache.read(p, IknowCache::merge_options(cache_options, options))
      Rails.logger.debug("=> #{v.inspect}") if DEBUG
      v
    end

    def write(key, value, parent_path: nil, **options)
      p = path(key, parent_path)
      Rails.logger.debug("Cache Store: #{p} (#{IknowCache::merge_options(cache_options, options).inspect})") if DEBUG
      Rails.cache.write(p, value, IknowCache::merge_options(cache_options, options))
    end

    def delete(key, parent_path: nil, **options)
      p = path(key, parent_path)
      Rails.logger.debug("Cache Delete: #{p}") if DEBUG
      Rails.cache.delete(p, IknowCache::merge_options(cache_options, options))
    end

    def read_multi(keys)
      return {} if keys.blank?
      key_paths = path_multi(keys)
      path_keys = key_paths.invert

      Rails.logger.debug("Cache Multi-Read: #{paths.keys.inspect}") if DEBUG
      raw = Rails.cache.read_multi(*key_paths.values)
      vs = raw.each_with_object({}) do |(path, value), h|
        h[path_keys[path]] = value
      end
      Rails.logger.debug("=> #{vs.inspect}") if DEBUG
      vs
    end

    def write_multi(entries, options = nil)
      return {} if entries.blank?
      key_paths = path_multi(entries.keys)
      options = IknowCache::merge_options(cache_options, options)

      entries.each do |key, value|
        Rails.logger.debug("Cache Multi-Write: #{key_paths[key]}") if DEBUG
        Rails.cache.write(key_paths[key], value, options)
      end
    end

    # delegate :parent_path, :key, to: :cache_group

    private

    def path(key, parent_path = nil)
      group_path = @cache_group.path(key, parent_path)
      path_string(group_path)
    end

    def path_multi(keys)
      @cache_group.path_multi(keys).each_with_object({}) do |(key, group_path), h|
        h[key] = path_string(group_path)
      end
    end

    def path_string(group_path)
      "#{group_path}/#{self.name}"
    end
  end

  def self.merge_options(parent_options, options)
    if parent_options.blank?
      options
    elsif options.blank?
      parent_options
    else
      parent_options.merge(options)
    end
  end
end
