class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :bootstrap_mode?

  private
    # 系统尚无任何校区（初始部署或校区刚被全部删除）时为引导模式：
    # 允许已登录用户进入「学校管理」创建校区，否则将永远无法恢复配置
    def bootstrap_mode?
      authenticated? && Current.campuse.nil? && !Campuse.exists?
    end
end
