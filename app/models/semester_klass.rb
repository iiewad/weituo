class SemesterKlass < ApplicationRecord
  belongs_to :klass
  belongs_to :semester
  has_many :courses, dependent: :destroy
  belongs_to :grade
  has_many :klass_students, dependent: :destroy
  has_many :students, through: :klass_students

  after_create :create_courses

  def create_courses
    self.times.times do |i|
      courses.find_or_create_by(seq: i + 1, semester_klass: self)
    end
  end

  def self.ransackable_associations(auth_object = nil)
    [ "courses", "grade", "klass", "klass_students", "semester", "students" ]
  end
  def self.ransackable_attributes(auth_object = nil)
  [ "created_at", "grade_id", "id", "klass_id", "semester_id", "times", "updated_at" ]
  end


  def name
    "#{grade.level}#{klass.subject.name[0]}#{Klass::GENRE_MAP_REVERSE[klass.genre][0]}#{klass.seq}"
  end

  def students_text
    students.map(&:name).join("\n")
  end
end
