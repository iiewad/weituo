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

ActiveRecord::Schema[8.1].define(version: 2026_02_05_101336) do
  create_table "campuses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "school_id", null: false
  end

  create_table "grade_subjects", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "grade_id", null: false
    t.bigint "school_id", null: false
    t.bigint "subject_id", null: false
    t.index ["grade_id"], name: "index_grade_subjects_on_grade_id"
    t.index ["school_id"], name: "index_grade_subjects_on_school_id"
    t.index ["subject_id"], name: "index_grade_subjects_on_subject_id"
  end

  create_table "grades", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "level", null: false
    t.string "name", null: false
  end

  create_table "guardians", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone", null: false
    t.string "relationship"
    t.bigint "student_id", null: false
  end

  create_table "klass_students", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "join_date"
    t.bigint "klass_id", null: false
    t.date "quit_date"
    t.integer "status", default: 1
    t.date "stop_date"
    t.bigint "student_id", null: false
  end

  create_table "klasses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "campuse_id", null: false
    t.string "genre", null: false
    t.bigint "grade_id", null: false
    t.bigint "semester_id", null: false
    t.integer "seq", null: false
    t.bigint "subject_id", null: false
    t.bigint "teacher_id", null: false
    t.integer "times", null: false
  end

  create_table "schools", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "semesters", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "end_date", null: false
    t.string "name", null: false
    t.bigint "school_id", null: false
    t.date "start_date", null: false
  end

  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "students", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "birthday"
    t.bigint "campuse_id", null: false
    t.datetime "created_at", null: false
    t.string "gender"
    t.bigint "grade_id"
    t.date "in_date"
    t.integer "layer"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
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
    t.index ["user_id"], name: "index_user_campuses_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_users_on_name", unique: true
  end

  add_foreign_key "sessions", "users"
  add_foreign_key "user_campuses", "campuses"
  add_foreign_key "user_campuses", "schools"
  add_foreign_key "user_campuses", "users"
end
