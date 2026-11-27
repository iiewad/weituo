require "test_helper"

class Admin::ReferralsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index shows referral summary, ranking and records" do
    get admin_referrals_path

    assert_response :success
    assert_select "h1", text: "推荐看板"
    assert_includes response.body, "共 4 条推荐关系"
    assert_includes response.body, "推荐排行"
    assert_includes response.body, "9_学生1"
    assert_includes response.body, "7_学生1"
    assert_includes response.body, "3 人"
  end

  test "index offers an export link carrying the current filters" do
    get admin_referrals_path

    assert_response :success
    assert_select "a[href*='export'][href*='/admin/referrals']", text: /导出报表/
  end

  test "index filters referrals by referrer grade" do
    get admin_referrals_path(grade_id: grades(:grade_7).id)
    assert_response :success
    assert_includes response.body, "暂无推荐记录"
    assert_select "select[name='grade_id'] option[selected][value='#{grades(:grade_7).id}']"
  end

  test "index filters referrals by period" do
    student_referrals(:referral_1).update!(created_at: 4.months.ago)

    get admin_referrals_path(period: "quarter")
    assert_response :success
    assert_includes response.body, "共 3 条推荐关系"
    assert_select "select[name='period'] option[selected][value='quarter']"

    get admin_referrals_path(period: "year")
    assert_response :success
    assert_includes response.body, "共 4 条推荐关系"
  end

  test "index ignores an unknown period" do
    get admin_referrals_path(period: "bogus")

    assert_response :success
    assert_includes response.body, "共 4 条推荐关系"
  end

  test "index name search matches the referrer and filters only the detail table" do
    get admin_referrals_path(name: "9_学生2")

    assert_response :success
    # 总览（副标题/卡片）按年级+时间口径，不受人名搜索影响
    assert_includes response.body, "共 4 条推荐关系"
    # 明细只保留命中记录：推荐人 9_学生2 → 被推荐 7_学生4
    assert_includes response.body, "7_学生4"
    assert_not_includes response.body, "7_学生3"
  end

  test "index name search matches the referred student" do
    get admin_referrals_path(name: "7_学生2")

    assert_response :success
    assert_includes response.body, "共 4 条推荐关系"
    assert_includes response.body, "7_学生2"
    assert_not_includes response.body, "7_学生4"
  end

  test "index honors the per_page option" do
    get admin_referrals_path(per_page: 50)

    assert_response :success
    assert_select "select#referrals-per-page option[selected][value='50']"
  end

  test "index combines grade and name filters on the detail table" do
    get admin_referrals_path(grade_id: grades(:grade_9).id, name: "9_学生2")

    assert_response :success
    # 明细只剩推荐人 9_学生2 的 referral_4；其余三条（推荐人 9_学生1）被排除
    assert_includes response.body, "7_学生4"
    assert_not_includes response.body, "7_学生1"
  end

  test "exports the referral dashboard as xlsx" do
    get export_admin_referrals_path

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])

    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    sheets = workbook.read("xl/workbook.xml").force_encoding("UTF-8")
    assert_includes sheets, "推荐汇总"
    assert_includes sheets, "推荐明细"

    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "推荐排行（前10）"
    assert_includes strings, "被推荐学员年级分布"
    assert_includes strings, "筛选条件：全部推荐"
    assert_includes strings, "推荐人年级"
    assert_includes strings, "9_学生1"
    assert_includes strings, "7_学生1"
  end

  test "export carries the filters into the sheet and excludes filtered-out records" do
    get export_admin_referrals_path(grade_id: grades(:grade_7).id)

    assert_response :success
    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "筛选条件：推荐人年级：七年级"
    assert_not_includes strings, "9_学生1"
  end

  test "export combines grade and period filters in the summary" do
    student_referrals(:referral_1).update!(created_at: 4.months.ago)

    get export_admin_referrals_path(grade_id: grades(:grade_9).id, period: "quarter")

    assert_response :success
    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    assert_includes strings, "筛选条件：推荐人年级：九年级 · 时间范围：近3个月"
  end

  test "export applies the name filter to the detail sheet only" do
    get export_admin_referrals_path(name: "9_学生2")

    assert_response :success
    workbook = Zip::File.open_buffer(StringIO.new(response.body))
    strings = workbook.read("xl/sharedStrings.xml").force_encoding("UTF-8")
    # 明细页筛选条件含人名搜索；明细只导出命中记录
    assert_includes strings, "姓名搜索：9_学生2"
    assert_includes strings, "7_学生4"
    assert_not_includes strings, "7_学生3"
  end
end
