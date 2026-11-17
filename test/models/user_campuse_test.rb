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

  test "school is derived from the selected campus" do
    uc = UserCampuse.new(user: users(:one), campuse: campuses(:campuse_1), role: "manager")

    assert uc.valid?
    assert_equal campuses(:campuse_1).school_id, uc.school_id
  end

  test "grade ids from form are normalized" do
    uc = UserCampuse.new(grade_ids: [ "", "7", "7", "9" ])

    assert_equal [ 7, 9 ], uc.grade_ids
  end

  test "role label falls back to a readable value" do
    assert_equal "超级管理员", UserCampuse.new(role: "admin").role_label
    assert_equal "未设置", UserCampuse.new(role: "").role_label
  end
end
