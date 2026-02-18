class Teacher < ApplicationRecord
  belongs_to :subject
  belongs_to :campuse

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
end
