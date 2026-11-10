require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "grade ids and grades are scoped by campuse" do
    user = users(:one)
    campuse_id = campuses(:campuse_1).id

    assert_equal [ "7", "8", "9" ], user.grade_ids_by_campuse(campuse_id)
    assert_equal [ "七年级", "八年级", "九年级" ], user.grades_by_campuse(campuse_id).order(:level).pluck(:name)
  end

  test "subjects by campuse come from the school grade subjects" do
    subjects = users(:one).subjects_by_campuse(campuses(:campuse_1).id).order(:id)
    assert_equal [ "数学", "英语" ], subjects.pluck(:name)
  end

  test "role check is scoped by campuse" do
    user = users(:one)
    campuse_id = campuses(:campuse_1).id

    assert user.has_role_by_campuse_id(campuse_id, "admin")
    assert_not user.has_role_by_campuse_id(campuse_id, "manager")
    assert_not user.has_role_by_campuse_id(999, "admin")
  end

  test "manager only sees its own grade ids" do
    assert_equal [ "8", "9" ], users(:two).grade_ids_by_campuse(campuses(:campuse_1).id)
  end

  test "authenticates with the configured password" do
    assert users(:one).authenticate("password")
    assert_not users(:one).authenticate("wrong")
  end
end
