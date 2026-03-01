require "test_helper"

class KlassStudentTest < ActiveSupport::TestCase
  test "reserved? should return true if the student is in the previous semester klass" do
    ks = klass_students(:ks_2)
    assert ks.reserved?
  end

  test "expand? should return true if the student is not in the previous semester klass" do
    student = students(:student_7_10)
    sk = semester_klasses(:sk_eng_1)
    student.join_klass(sk)
    ks = sk.klass_students.find_by(student_id: student.id)
    assert ks.expand?
  end
end
