require "test_helper"

class UserCampuseTest < ActiveSupport::TestCase
  test "belongs to user, school and campuse" do
    uc = user_campuses(:uc_1)
    assert_equal users(:one), uc.user
    assert_equal schools(:school_1), uc.school
    assert_equal campuses(:campuse_1), uc.campuse
  end

  test "roles are declared" do
    assert_equal "超级管理员", UserCampuse::ROLES[:admin]
    assert_equal "管理员", UserCampuse::ROLES[:manager]
  end
end
