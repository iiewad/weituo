# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_26_105845) do
  create_table "attendances", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "klass_student_id"
    t.integer "status", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "marked_by_id"
    t.bigint "transfer_target_klass_id"
    t.index ["course_id", "klass_student_id"], name: "index_attendances_on_course_id_and_klass_student_id", unique: true
    t.index ["klass_student_id"], name: "index_attendances_on_klass_student_id"
    t.index ["marked_by_id"], name: "index_attendances_on_marked_by_id"
    t.index ["transfer_target_klass_id"], name: "index_attendances_on_transfer_target_klass_id"
  end

  create_table "campuses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "school_id", null: false
    t.index ["school_id"], name: "index_campuses_on_school_id"
  end

  create_table "courses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "semester_klass_id"
    t.integer "seq", null: false
    t.date "start_date"
    t.index ["semester_klass_id", "seq"], name: "index_courses_on_semester_klass_id_and_seq", unique: true
  end

  create_table "day_schools", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "campuse_id", null: false
    t.string "name"
    t.index ["campuse_id"], name: "index_day_schools_on_campuse_id"
  end

  create_table "grade_subjects", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "grade_id", null: false
    t.bigint "school_id", null: false
    t.bigint "subject_id", null: false
    t.bigint "semester_id", null: false
    t.integer "times", default: 16, null: false
    t.index ["grade_id"], name: "index_grade_subjects_on_grade_id"
    t.index ["school_id", "semester_id", "grade_id", "subject_id"], name: "index_grade_subjects_on_school_semester_grade_subject", unique: true
    t.index ["school_id"], name: "index_grade_subjects_on_school_id"
    t.index ["semester_id"], name: "index_grade_subjects_on_semester_id"
    t.index ["subject_id"], name: "index_grade_subjects_on_subject_id"
  end

  create_table "grades", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "level", null: false
    t.string "name", null: false
  end

  create_table "guardians", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "phone", null: false
    t.string "relationship"
    t.bigint "student_id", null: false
    t.string "occupation"
    t.index ["student_id"], name: "index_guardians_on_student_id"
  end

  create_table "klass_students", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "semester_klass_id"
    t.integer "status", default: 1
    t.bigint "student_id", null: false
    t.datetime "archived_at"
    t.index ["archived_at"], name: "index_klass_students_on_archived_at"
    t.index ["semester_klass_id", "student_id"], name: "index_klass_students_on_semester_klass_id_and_student_id", unique: true
    t.index ["student_id"], name: "index_klass_students_on_student_id"
  end

  create_table "schools", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "semester_klasses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "campuse_id"
    t.datetime "created_at", null: false
    t.string "genre"
    t.bigint "grade_id", null: false
    t.bigint "semester_id", null: false
    t.integer "seq"
    t.bigint "subject_id"
    t.bigint "teacher_id"
    t.integer "times", null: false
    t.datetime "updated_at", null: false
    t.integer "phase", default: 1, null: false
    t.index ["campuse_id", "semester_id"], name: "index_semester_klasses_on_campuse_id_and_semester_id"
    t.index ["grade_id"], name: "fk_rails_bdc752021b"
    t.index ["semester_id", "campuse_id", "grade_id", "subject_id", "genre", "seq", "phase"], name: "index_semester_klasses_on_business_key", unique: true
    t.index ["subject_id"], name: "fk_rails_9c09232f85"
    t.index ["teacher_id"], name: "index_semester_klasses_on_teacher_id"
  end

  create_table "semesters", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "end_date", null: false
    t.string "name", null: false
    t.bigint "school_id", null: false
    t.integer "seq"
    t.date "start_date", null: false
    t.index ["school_id", "seq"], name: "index_semesters_on_school_id_and_seq", unique: true
    t.index ["school_id"], name: "index_semesters_on_school_id"
  end

  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "student_referrals", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "referrer_id", null: false
    t.bigint "referred_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["referred_id"], name: "index_student_referrals_on_referred_id", unique: true
    t.index ["referrer_id"], name: "index_student_referrals_on_referrer_id"
  end

  create_table "students", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "birthday"
    t.bigint "campuse_id", null: false
    t.datetime "created_at", null: false
    t.bigint "day_school_id"
    t.string "gender"
    t.bigint "grade_id"
    t.date "in_date"
    t.integer "layer"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.text "remark"
    t.integer "name_seq", default: 1, null: false
    t.string "address"
    t.index ["campuse_id", "name", "name_seq"], name: "index_students_on_campuse_id_and_name_and_name_seq", unique: true
    t.index ["campuse_id"], name: "index_students_on_campuse_id"
    t.index ["day_school_id"], name: "index_students_on_day_school_id"
    t.index ["grade_id"], name: "index_students_on_grade_id"
  end

  create_table "subjects", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
  end

  create_table "teachers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "campuse_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.bigint "subject_id", null: false
    t.datetime "archived_at"
    t.index ["campuse_id"], name: "index_teachers_on_campuse_id"
    t.index ["subject_id"], name: "index_teachers_on_subject_id"
  end

  create_table "user_campuses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "campuse_id", null: false
    t.datetime "created_at", null: false
    t.json "grade_ids"
    t.string "role", default: ""
    t.bigint "school_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["campuse_id"], name: "index_user_campuses_on_campuse_id"
    t.index ["school_id"], name: "index_user_campuses_on_school_id"
    t.index ["user_id", "campuse_id"], name: "index_user_campuses_on_user_id_and_campuse_id", unique: true
    t.index ["user_id"], name: "index_user_campuses_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "guide_completed_at"
    t.index ["name"], name: "index_users_on_name", unique: true
  end

  add_foreign_key "attendances", "courses"
  add_foreign_key "attendances", "klass_students"
  add_foreign_key "attendances", "semester_klasses", column: "transfer_target_klass_id", on_delete: :nullify
  add_foreign_key "attendances", "users", column: "marked_by_id", on_delete: :nullify
  add_foreign_key "campuses", "schools"
  add_foreign_key "courses", "semester_klasses"
  add_foreign_key "day_schools", "campuses"
  add_foreign_key "grade_subjects", "grades"
  add_foreign_key "grade_subjects", "schools"
  add_foreign_key "grade_subjects", "semesters"
  add_foreign_key "grade_subjects", "subjects"
  add_foreign_key "guardians", "students"
  add_foreign_key "klass_students", "semester_klasses"
  add_foreign_key "klass_students", "students"
  add_foreign_key "semester_klasses", "campuses"
  add_foreign_key "semester_klasses", "grades"
  add_foreign_key "semester_klasses", "semesters"
  add_foreign_key "semester_klasses", "subjects"
  add_foreign_key "semester_klasses", "teachers"
  add_foreign_key "semesters", "schools"
  add_foreign_key "sessions", "users"
  add_foreign_key "student_referrals", "students", column: "referred_id"
  add_foreign_key "student_referrals", "students", column: "referrer_id"
  add_foreign_key "students", "campuses"
  add_foreign_key "students", "day_schools"
  add_foreign_key "students", "grades"
  add_foreign_key "teachers", "campuses"
  add_foreign_key "teachers", "subjects"
  add_foreign_key "user_campuses", "campuses"
  add_foreign_key "user_campuses", "schools"
  add_foreign_key "user_campuses", "users"
end
