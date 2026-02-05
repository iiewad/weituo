# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

school = School.first
(1..10).each do |i|
  Grade.find_or_create_by!(name: "年级#{i}", level: i.to_s)
end
%w[数学 英语 物理 化学].each do |name|
  subject = Subject.find_or_create_by!(name: name, code: name.downcase)
  5.times do |i|
    campuse = school.campuses.order('RAND()').first
    subject.teachers.create!(name: "教师#{i}", phone: "1380000#{i}00", campuse_id: campuse.id)
  end
end

1000.times do |i|
  school = School.first
  campuse = school.campuses.order('RAND()').first
  grade = Grade.find(rand(1..10))
  campuse.students.create!(name: "学员#{i}", phone: "1380000#{i}00", grade: grade, campuse: campuse)
end
