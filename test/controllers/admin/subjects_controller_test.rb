require "test_helper"

class Admin::SubjectsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "create adds a subject" do
    assert_difference -> { Subject.count }, 1 do
      post admin_subjects_path, params: { subject: { code: "BIO", name: "生物" } }
    end

    assert_redirected_to admin_grade_subjects_path
    assert_match "科目已添加", flash[:notice]
  end

  test "create rejects duplicate code" do
    assert_no_difference -> { Subject.count } do
      post admin_subjects_path, params: { subject: { code: subjects(:math).code, name: "重复科目" } }
    end

    assert_match "添加失败", flash[:alert]
  end

  test "update changes a subject" do
    subject = Subject.create!(code: "BIO", name: "生物")

    patch admin_subject_path(subject), params: { subject: { code: "BIO2", name: "生物学" } }

    assert_redirected_to admin_grade_subjects_path
    assert_equal "BIO2", subject.reload.code
    assert_equal "生物学", subject.name
  end

  test "cannot delete a subject used by teachers" do
    subject = subjects(:math)
    assert Teacher.exists?(subject_id: subject.id)

    assert_no_difference -> { Subject.count } do
      delete admin_subject_path(subject)
    end

    assert_match "教师", flash[:alert]
  end

  test "deletes an unused subject" do
    subject = Subject.create!(code: "BIO", name: "生物")

    assert_difference -> { Subject.count }, -1 do
      delete admin_subject_path(subject)
    end

    assert_match "科目已删除", flash[:notice]
  end

  test "managers cannot maintain subjects" do
    sign_in_as users(:two)

    post admin_subjects_path, params: { subject: { code: "BIO", name: "生物" } }

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end
end
