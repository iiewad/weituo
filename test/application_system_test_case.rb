require "test_helper"

# 本机 chromedriver 的 HTTP 调用若走 HTTP_PROXY 会超时；NO_PROXY 里的 `127.*` 对 Net::HTTP 不生效，补一条精确匹配。
ENV["no_proxy"] = [ ENV["no_proxy"], "127.0.0.1", "localhost" ].compact.join(",")
ENV["NO_PROXY"] = ENV["no_proxy"]

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # 本地 WSL 只有 chromium-browser(snap 包装)，GitHub runner 自带 google-chrome。
  CHROME_BIN = ENV["CHROME_BIN"] || %w[
    /usr/bin/google-chrome
    /usr/bin/google-chrome-stable
    /usr/bin/chromium
    /usr/bin/chromium-browser
  ].find { |path| File.executable?(path) }

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.binary = CHROME_BIN if CHROME_BIN
  end

  private
    def sign_in(name: "user1", password: "password")
      visit new_session_path
      fill_in "用户名", with: name
      fill_in "密码", with: password
      click_button "登录"
      assert_current_path root_path
    end
end
