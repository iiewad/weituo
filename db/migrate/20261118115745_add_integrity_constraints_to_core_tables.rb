class AddIntegrityConstraintsToCoreTables < ActiveRecord::Migration[8.1]
  def change
    add_index :attendances, [ :course_id, :klass_student_id ], unique: true
    add_index :attendances, :klass_student_id

    add_index :klass_students, [ :semester_klass_id, :student_id ], unique: true
    add_index :klass_students, :student_id

    add_index :courses, [ :semester_klass_id, :seq ], unique: true

    add_index :semester_klasses,
      [ :semester_id, :campuse_id, :grade_id, :subject_id, :genre, :seq ],
      unique: true,
      name: "index_semester_klasses_on_business_key"
    add_index :semester_klasses, [ :campuse_id, :semester_id ]
    add_index :semester_klasses, :teacher_id

    add_index :students, :campuse_id
    add_index :students, :grade_id
    add_index :students, :day_school_id

    add_index :teachers, :campuse_id
    add_index :teachers, :subject_id
    add_index :guardians, :student_id
    add_index :day_schools, :campuse_id
    add_index :campuses, :school_id
    add_index :semesters, :school_id
    add_index :grade_subjects, [ :school_id, :grade_id, :subject_id ], unique: true
    add_index :user_campuses, [ :user_id, :campuse_id ], unique: true

    add_foreign_key :campuses, :schools
    add_foreign_key :semesters, :schools
    add_foreign_key :day_schools, :campuses
    add_foreign_key :grade_subjects, :schools
    add_foreign_key :grade_subjects, :grades
    add_foreign_key :grade_subjects, :subjects
    add_foreign_key :students, :campuses
    add_foreign_key :students, :grades
    add_foreign_key :students, :day_schools
    add_foreign_key :guardians, :students
    add_foreign_key :teachers, :campuses
    add_foreign_key :teachers, :subjects
    add_foreign_key :semester_klasses, :campuses
    add_foreign_key :semester_klasses, :semesters
    add_foreign_key :semester_klasses, :grades
    add_foreign_key :semester_klasses, :subjects
    add_foreign_key :semester_klasses, :teachers
    add_foreign_key :courses, :semester_klasses
    add_foreign_key :klass_students, :semester_klasses
    add_foreign_key :klass_students, :students
    add_foreign_key :attendances, :courses
    add_foreign_key :attendances, :klass_students
  end
end
