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

  test "add by text returns counts and skips headers and duplicates" do
    text = [ "日校名称", "七中,备注", "七中", " " ].join("\n")

    created = skipped = nil
    assert_difference -> { DaySchool.count }, 1 do
      created, skipped = DaySchool.add_by_text(campuses(:campuse_1).id, text)
    end

    assert_equal 1, created
    assert_equal 1, skipped
    assert DaySchool.exists?(name: "七中", campuse: campuses(:campuse_1))
  end

  test "name is required and unique within a campus" do
    campuse = campuses(:campuse_1)
    existing = day_schools(:one)

    duplicate = DaySchool.new(name: existing.name, campuse: campuse)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "在当前校区已存在"

    assert_not DaySchool.new(name: "", campuse: campuse).valid?
  end

  test "the same name can be used by another campus" do
    other_campuse = Campuse.create!(name: "第二校区", school: schools(:school_1))

    assert DaySchool.new(name: day_schools(:one).name, campuse: other_campuse).valid?
  end
end
