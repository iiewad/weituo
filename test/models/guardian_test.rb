require "test_helper"

class GuardianTest < ActiveSupport::TestCase
  test "add by text attaches a guardian to a known student" do
    assert_difference -> { Guardian.count }, 1 do
      Guardian.add_by_text(campuses(:campuse_1).id, "家长,13800000000,父亲,7_学生1")
    end
    assert_equal students(:student_7_1), Guardian.find_by!(name: "家长").student
  end

  test "add by text skips unknown students" do
    assert_no_difference -> { Guardian.count } do
      Guardian.add_by_text(campuses(:campuse_1).id, "家长,138,父亲,不存在的学员")
    end
  end
end
