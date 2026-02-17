# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
school = School.find_or_create_by!(name: "维拓")
campuse = school.campuses.find_or_create_by!(name: "校区1")
campuse2 = school.campuses.find_or_create_by!(name: "校区2")

user_admin = User.create!(name: "admin", password: "password")
UserCampuse.find_or_create_by!(user_id: user_admin.id, campuse_id: campuse.id, role: "admin", school_id: school.id)
UserCampuse.find_or_create_by!(user_id: user_admin.id, campuse_id: campuse2.id, role: "admin", school_id: school.id)
campuse_manager = User.create!(name: "user1", password: "password")
UserCampuse.find_or_create_by!(user_id: campuse_manager.id, campuse_id: campuse.id, role: "manager", school_id: school.id)  
campuse2_manager = User.create!(name: "user2", password: "password")
UserCampuse.find_or_create_by!(user_id: campuse2_manager.id, campuse_id: campuse2.id, role: "manager", school_id: school.id)

campuse.day_schools.find_or_create_by!(name: "一中", campuse_id: campuse.id)
campuse.day_schools.find_or_create_by!(name: "二中", campuse_id: campuse.id)
campuse.day_schools.find_or_create_by!(name: "三中", campuse_id: campuse.id)
campuse.day_schools.find_or_create_by!(name: "四中", campuse_id: campuse.id)
campuse2.day_schools.find_or_create_by!(name: "一中", campuse_id: campuse2.id)
campuse2.day_schools.find_or_create_by!(name: "二中", campuse_id: campuse2.id)
campuse2.day_schools.find_or_create_by!(name: "三中", campuse_id: campuse2.id)
campuse2.day_schools.find_or_create_by!(name: "四中", campuse_id: campuse2.id)

# 根据春季/暑假/秋季/寒假 确定学期时间
Semester.find_or_create_by!(name: "#{Date.today.year}学年第一学期", start_date: Date.today, end_date: Date.today + 1.month, school_id: school.id)
Semester.find_or_create_by!(name: "#{Date.today.year}学年第二学期", start_date: Date.today + 1.month, end_date: Date.today + 2.months, school_id: school.id)
Semester.find_or_create_by!(name: "#{Date.today.year}学年第三学期", start_date: Date.today + 2.months, end_date: Date.today + 3.months, school_id: school.id)
Semester.find_or_create_by!(name: "#{Date.today.year}学年第四学期", start_date: Date.today + 3.months, end_date: Date.today + 4.months, school_id: school.id)
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
  campuse.students.create!(name: "#{grade.level}学员#{i}", phone: "1380000#{i}00", grade: grade, campuse: campuse)
end
