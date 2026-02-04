# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end


(1..10).each do |i|
  Grade.create!(name: "年级#{i}", level: i.to_s)
end
%w[数学 英语 物理 化学].each do |name|
  Subject.create!(name: name, code: name.downcase)
end
