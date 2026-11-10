require "test_helper"

class KlassStudentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "destroy removes the enrollment" do
    sk = semester_klasses(:sk_math_1)
    ks = klass_students(:ks_1)

    assert_difference -> { sk.klass_students.count }, -1 do
      delete admin_semester_klass_klass_student_path(sk, ks)
    end
    assert_redirected_to admin_semester_klass_path(sk)
  end
end
