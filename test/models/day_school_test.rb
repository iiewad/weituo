require "test_helper"

class DaySchoolTest < ActiveSupport::TestCase
  test "add by text creates day schools for a campuse" do
    assert_difference -> { DaySchool.count }, 2 do
      DaySchool.add_by_text(campuses(:campuse_1).id, "四中\n五中")
    end
    assert DaySchool.find_by(name: "四中", campuse_id: campuses(:campuse_1).id)
  end

  test "add by text is idempotent" do
    DaySchool.add_by_text(campuses(:campuse_1).id, "六中")
    assert_no_difference -> { DaySchool.count } do
      DaySchool.add_by_text(campuses(:campuse_1).id, "六中")
    end
  end
end
