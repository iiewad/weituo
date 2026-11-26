require "test_helper"

class Admin::DaySchoolsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index lists day schools of the current campus with student counts" do
    get admin_day_schools_path

    assert_response :success
    assert_select "h1", text: "日校管理"
    assert_select "td", text: day_schools(:one).name
    assert_select "td", text: /\d+ 人/
  end

  test "create adds a day school to the current campus" do
    assert_difference -> { DaySchool.count }, 1 do
      post admin_day_schools_path, params: { day_school: { name: "新日校" } }
    end

    assert_redirected_to admin_day_schools_path
    assert DaySchool.exists?(name: "新日校", campuse: campuses(:campuse_1))
    assert_match "日校已添加", flash[:notice]
  end

  test "create rejects a duplicate name in the same campus" do
    assert_no_difference -> { DaySchool.count } do
      post admin_day_schools_path, params: { day_school: { name: day_schools(:one).name } }
    end

    assert_redirected_to admin_day_schools_path
    assert_match "在当前校区已存在", flash[:alert]
  end

  test "create returns the new day school as json for the quick picker" do
    assert_difference -> { DaySchool.count }, 1 do
      post admin_day_schools_path, params: { day_school: { name: "快捷日校" } }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "快捷日校", body["name"]
    assert DaySchool.exists?(id: body["id"], campuse: campuses(:campuse_1))
  end

  test "create returns errors as json for a duplicate name" do
    assert_no_difference -> { DaySchool.count } do
      post admin_day_schools_path, params: { day_school: { name: day_schools(:one).name } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"].first, "已存在"
  end

  test "import creates day schools from pasted text" do
    assert_difference -> { DaySchool.count }, 2 do
      post import_admin_day_schools_path, params: { day_schools_text: "八中\n九中,备注" }
    end

    assert_redirected_to admin_day_schools_path
    assert_match "新增 2 个日校", flash[:notice]
    assert DaySchool.exists?(name: "八中", campuse: campuses(:campuse_1))
    assert DaySchool.exists?(name: "九中", campuse: campuses(:campuse_1))
  end

  test "import skips existing names" do
    post import_admin_day_schools_path, params: { day_schools_text: day_schools(:one).name }

    assert_redirected_to admin_day_schools_path
    assert_match "没有新增日校", flash[:alert]
  end

  test "import requires pasted text" do
    post import_admin_day_schools_path, params: { day_schools_text: "  " }

    assert_redirected_to admin_day_schools_path
    assert_match "请粘贴", flash[:alert]
  end

  test "update renames the day school" do
    day_school = day_schools(:one)

    put admin_day_school_path(day_school), params: { day_school: { name: "改名日校" } }

    assert_redirected_to admin_day_schools_path
    assert_equal "改名日校", day_school.reload.name
  end

  test "destroy removes a day school that has no students" do
    day_school = DaySchool.create!(name: "待删除日校", campuse: campuses(:campuse_1))

    assert_difference -> { DaySchool.count }, -1 do
      delete admin_day_school_path(day_school)
    end

    assert_redirected_to admin_day_schools_path
    assert_match "日校已删除", flash[:notice]
  end

  test "destroy refuses a day school that still has students" do
    day_school = day_schools(:one)

    assert_no_difference -> { DaySchool.count } do
      delete admin_day_school_path(day_school)
    end

    assert_redirected_to admin_day_schools_path
    assert_match "不能删除", flash[:alert]
  end

  test "managers cannot manage day schools" do
    sign_in_as users(:two)

    get admin_day_schools_path

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end
end
