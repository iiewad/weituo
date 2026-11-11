require "test_helper"

class Admin::CampusesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "switch thread campuse selects the requested campus" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))

    get switch_thread_campuse_admin_school_campuse_path(schools(:school_1), other), headers: { "HTTP_REFERER" => root_path }

    assert_redirected_to root_path
    assert_equal other, Thread.current[:campuse]
  end

  test "update" do
    put admin_school_campuse_path(schools(:school_1), campuses(:campuse_1)), params: { campuse: { name: "新校区" } }
    assert_redirected_to admin_schools_path
    assert_equal "新校区", campuses(:campuse_1).reload.name
  end
end
