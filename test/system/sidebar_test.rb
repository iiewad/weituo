require "application_system_test_case"

class SidebarTest < ApplicationSystemTestCase
  setup { sign_in }

  test "侧栏可折叠为图标条并跨页面保持" do
    assert_selector "span.wt-sidebar-text", visible: :visible
    assert_no_selector "html.wt-sidebar-collapsed"

    find("[data-sidebar-toggle]").click

    assert_selector "html.wt-sidebar-collapsed"
    assert_no_selector "span.wt-sidebar-text", visible: :visible

    # localStorage 里的状态在重新加载后仍然生效
    visit root_path
    assert_selector "html.wt-sidebar-collapsed"

    find("[data-sidebar-toggle]").click
    assert_no_selector "html.wt-sidebar-collapsed"
    assert_selector "span.wt-sidebar-text", visible: :visible
  end

  test "图标条状态下仍可通过图标导航" do
    find("[data-sidebar-toggle]").click

    find("a[title='班级报表']").click

    assert_current_path statement_admin_semester_klasses_path
    assert_text "班级报表"
  end
end
