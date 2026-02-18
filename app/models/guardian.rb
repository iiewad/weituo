class Guardian < ApplicationRecord
    belongs_to :student

    def self.add_by_text(campuse_id, str)
        campuse = Campuse.find(campuse_id)
        str.split("\n").each do |line|
          name, phone, relation, student_name = line.split(",")
          student = campuse.students.find_by(name: student_name)
          next if student.blank?
          guardian = Guardian.find_or_create_by(name: name, phone: phone.delete('"'), relationship: relation, student_id: student.id)
        end
    end
end
