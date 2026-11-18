class Student < ApplicationRecord
  paginates_per 30
  validates :name, presence: true

  belongs_to :day_school, optional: true
  belongs_to :campuse
  belongs_to :grade, optional: true
  has_many :guardians, dependent: :destroy
  has_many :klass_students, dependent: :destroy
  has_many :klasses, through: :klass_students
  accepts_nested_attributes_for :guardians, reject_if: :all_blank, allow_destroy: true

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "grade_id" ]
  end

  def join_klass(sk, course_seq: 1)
    return if sk.grade_id != grade_id || sk.campuse_id != campuse_id
    ks = klass_students.find_or_create_by(semester_klass_id: sk.id)
    course = sk.courses.find_by(seq: course_seq)
    return if course.blank?

    sk.courses.where("seq < ?", course_seq).each do |course|
      attendance = course.attendances.find_or_create_by(klass_student_id: ks.id)
      attendance.update!(status: "absent")
    end
    sk.courses.where("seq >= ? AND start_date IS NOT NULL", course_seq).each do |course|
      attendance = course.attendances.find_or_create_by(klass_student_id: ks.id)
    end
  end

  def update_grade
    target_grade = Grade.find_by(level: grade.level.to_i + 1)
    update!(grade_id: target_grade.id) if target_grade.present?
  end

  # 按 CSV 行导入学员：姓名,性别,生日,年级level,层级,入学日期,日校[,监护人姓名,监护人电话,监护关系]
  # 监护人字段可选；返回 [新增人数, 跳过行数]。
  def self.add_by_text(campuse_id, str, grade_ids: nil)
    campuse = Campuse.find(campuse_id)
    created = 0
    skipped = 0

    str.to_s.split("\n").each do |line|
      next if line.strip.blank?

      name, gender, birthday, grade_level, layer, in_date, day_school_name,
        guardian_name, guardian_phone, guardian_relationship = line.split(",").map(&:strip)
      grade = Grade.find_by(level: grade_level)
      day_school = campuse.day_schools.find_by(name: day_school_name)

      if name.blank? || grade.blank? || day_school.blank? || (grade_ids && !grade_ids.include?(grade.id))
        skipped += 1
        next
      end

      gender = {
        "男" => "male", "女" => "female",
        "male" => "male", "female" => "female"
      }[gender]

      student = find_or_create_by(
        name: name,
        gender: gender,
        birthday: birthday,
        grade_id: grade.id,
        layer: layer,
        in_date: in_date,
        day_school_id: day_school.id,
        campuse_id: campuse_id
      )

      if guardian_name.present? && guardian_phone.present?
        student.guardians.find_or_create_by(name: guardian_name, phone: guardian_phone) do |guardian|
          guardian.relationship = guardian_relationship.presence
        end
      end

      student.previously_new_record? ? created += 1 : skipped += 1
    end

    [ created, skipped ]
  end
end
