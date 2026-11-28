# 页面提示下方的明细列表（如批量导入时未导入的学员）。明细可能有几百行，cookie session 上限约 4KB
# 放不下，所以内容存进缓存，flash 里只带一个随机令牌，由 admin/shared/_alert 取回并展示。
class FlashDetails
  PREFIX = "flash_details/"
  EXPIRES_IN = 10.minutes

  def self.store(details)
    token = SecureRandom.hex(16)
    Rails.cache.write("#{PREFIX}#{token}", details, expires_in: EXPIRES_IN)
    token
  end

  # 令牌对应的明细已被清理时返回 nil，由页面提示明细已过期
  def self.load(token)
    Rails.cache.read("#{PREFIX}#{token}") if token
  end
end
