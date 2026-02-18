class Student < ApplicationRecord
  paginates_per 30
  belongs_to :day_school, optional: true
  belongs_to :campuse
  belongs_to :grade, optional: true
  has_many :guardians, dependent: :destroy
  has_many :klass_students, dependent: :destroy
  has_many :klasses, through: :klass_students
  accepts_nested_attributes_for :guardians, reject_if: :all_blank, allow_destroy: true

  def self.ransackable_attributes(auth_object = nil)
    [ "name" ]
  end

  def self.add_by_text(campuse_id, str)
    campuse = Campuse.find(campuse_id)
    str.split("\n").each do |line|
      name, gender, birthday, grade, layer, in_date, day_school = line.split(",")
      grade = Grade.find_by(level: grade)
      next if grade.blank?
      day_school = campuse.day_schools.find_by(name: day_school)
      next if day_school.blank?
      student = Student.find_or_create_by(name: name, gender: gender, birthday: birthday, grade_id: grade.id, layer: layer, in_date: in_date, day_school_id: day_school.id, campuse_id: campuse_id)
    end
  end
end
