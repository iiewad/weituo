class Teacher < ApplicationRecord
  belongs_to :subject
  belongs_to :campuse

  validates :name, presence: true
  validate :subject_offered_by_school

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "phone", "subject_id", "campuse_id" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "subject", "campuse" ]
  end

  def self.add_by_text(campuse_id, str)
    campuse = Campuse.find(campuse_id)
    str.split("\n").each do |line|
      subject_name, name, phone = line.split(",")
      subject = Subject.find_by(name: subject_name)
      next if subject.blank?
      teacher = Teacher.find_or_create_by(name: name, phone: phone, subject_id: subject.id, campuse_id: campuse_id)
    end
  end

  def name_with_subject
    "#{subject.name} #{name}"
  end

  private
    def subject_offered_by_school
      return if subject.blank? || campuse.blank?
      return if campuse.school.subjects.exists?(id: subject_id)

      errors.add(:subject_id, "未在该学校开设")
    end
end
