# encoding: UTF-8

require 'test_helper'

class IknowCache::Test < MiniTest::Test
  def setup
    IknowCache.cache.clear
    @root = IknowCache::CacheGroup::ROOT_PATH
  end

  def test_path
    group = IknowCache.register_group(:group, :id)
    assert_equal("#{@root}/group/1/1/10", group.path(id: 10))
  end

  def test_child_path
    group = IknowCache.register_group(:parentgroup, :parentid)
    childgroup = group.register_child_group(:childgroup, :childid)
    assert_equal("#{@root}/parentgroup/1/1/10/childgroup/1/1/20", childgroup.path(parentid: 10, childid: 20))
  end

  def test_static_path
    group = IknowCache.register_group(:group, :id, static_version: 99)
    assert_equal("#{@root}/group/99/1/10", group.path(id: 10))
  end

  def test_cache_path_hash
    group = IknowCache.register_group(:group, :id)
    cache = group.register_cache(:store)
    assert_equal("#{@root}/group/1/1/10/store", cache.send(:path, { id: 10 }))
  end

  def test_cache_path_key
    group = IknowCache.register_group(:group, :id)
    cache = group.register_cache(:store)
    assert_equal("#{@root}/group/1/1/10/store", cache.send(:path, cache.key.new(10)))
  end

  def test_null_key
    group = IknowCache.register_group(:group, :id)
    ex = assert_raises(ArgumentError) do
      group.path(nil)
    end
    assert_match(/Missing required key/, ex.message)
  end

  def test_missing_key_hash
    group = IknowCache.register_group(:group, :id)
    ex = assert_raises(ArgumentError) do
      group.path({})
    end
    assert_match(/Missing required key/, ex.message)
  end

  def test_missing_key_struct
    group = IknowCache.register_group(:group, :id)
    ex = assert_raises(ArgumentError) do
      group.path(group.key.new(nil))
    end
    assert_match(/Missing required key/, ex.message)
  end

  def test_path_multi_hash
    group = IknowCache.register_group(:parentgroup, :parentid)
    childgroup = group.register_child_group(:childgroup, :childid)

    # Bump version of one child group
    childgroup.path(parentid: 10, childid: 1)
    childgroup.invalidate_cache_group(parentid: 10)

    paths = childgroup.path_multi([{parentid: 10, childid: 20}, {parentid: 11, childid: 21}])

    expected = {
      { parentid: 10, childid: 20 } => "#{@root}/parentgroup/1/1/10/childgroup/1/2/20",
      { parentid: 11, childid: 21 } => "#{@root}/parentgroup/1/1/11/childgroup/1/1/21",
    }

    assert_equal(expected, paths)
  end

  def test_path_multi_key
    group      = IknowCache.register_group(:parentgroup, :parentid)
    childgroup = group.register_child_group(:childgroup, :childid)

    # Bump version of one child group
    childgroup.path(parentid: 10, childid: 1)
    childgroup.invalidate_cache_group(parentid: 10)

    k1 = childgroup.key.new(10, 20)
    k2 = childgroup.key.new(11, 21)

    paths = childgroup.path_multi([childgroup.key.new(10, 20), childgroup.key.new(11, 21)])

    expected = {
      k1 => "#{@root}/parentgroup/1/1/10/childgroup/1/2/20",
      k2 => "#{@root}/parentgroup/1/1/11/childgroup/1/1/21",
    }

    assert_equal(expected, paths)
  end


  def test_invalidate_group
    group = IknowCache.register_group(:group, :id)
    assert_equal("#{@root}/group/1/1/10", group.path(id: 10))
    group.invalidate_cache_group
    assert_equal("#{@root}/group/1/2/10", group.path(id: 10))
  end

  def test_invalidate_child_group
    group = IknowCache.register_group(:parentgroup, :parentid, static_version: 5)
    childgroup = group.register_child_group(:childgroup, :childid, static_version: 6)
    assert_equal("#{@root}/parentgroup/5/1/10/childgroup/6/1/20", childgroup.path(parentid: 10, childid: 20))
    childgroup.invalidate_cache_group(parentid: 10)
    assert_equal("#{@root}/parentgroup/5/1/10/childgroup/6/2/20", childgroup.path(parentid: 10, childid: 20))
    assert_equal("#{@root}/parentgroup/5/1/11/childgroup/6/1/20", childgroup.path(parentid: 11, childid: 20))
  end


  def test_access
    group = IknowCache.register_group(:group, :id)
    cache = group.register_cache(:store)
    key = { id: 1 }

    assert_nil(cache.read(key))

    cache.write(key, "hello")

    assert_equal("hello", cache.read(key))

    assert_equal("hello", cache.fetch(key){ "goodbye" })

    cache.delete(key)

    assert_nil(cache.read(key))

    assert_equal("goodbye", cache.fetch(key){ "goodbye" })
  end

  def test_access_multi
    group = IknowCache.register_group(:group, :id)
    cache = group.register_cache(:store)

    data = {{id: 1} => "hello",
            {id: 2} => "goodbye"}

    cache.write_multi(data)

    values = cache.read_multi(data.keys)
    assert_equal(data, values)
  end

  def test_delete_from_group
    group = IknowCache.register_group(:group, :id)
    cache = group.register_cache(:store)

    cache.write({id: 1}, "hello")
    cache.write({id: 2}, "goodbye")

    group.delete_all(id: 1)

    assert_nil(cache.read(id: 1))
    assert_equal("goodbye", cache.read(id: 2))
  end

  def test_double_configre
    assert_raises(ArgumentError) do
      IknowCache.configure! {}
    end
  end
end
