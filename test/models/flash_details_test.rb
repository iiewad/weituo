require "test_helper"

class FlashDetailsTest < ActiveSupport::TestCase
  test "store returns a token that loads the same details" do
    token = nil
    with_memory_cache do
      token = FlashDetails.store([ "第 1 行 张三：年级 9 在本校区不存在" ])
      assert_equal [ "第 1 行 张三：年级 9 在本校区不存在" ], FlashDetails.load(token)
    end

    assert_match(/\A\h{32}\z/, token)
  end

  test "tokens are random so details of different requests never collide" do
    tokens = nil
    with_memory_cache do
      tokens = Array.new(3) { FlashDetails.store([]) }
    end

    assert_equal 3, tokens.uniq.size
  end

  test "load returns nil without a token or for expired details" do
    assert_nil FlashDetails.load(nil)

    with_memory_cache do
      token = FlashDetails.store([ "x" ])
      Rails.cache.clear
      assert_nil FlashDetails.load(token)
    end
  end

  private
    def with_memory_cache
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      Rails.cache = original_cache
    end
end
