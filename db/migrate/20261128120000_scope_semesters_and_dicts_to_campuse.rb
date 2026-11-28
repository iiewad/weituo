class ScopeSemestersAndDictsToCampuse < ActiveRecord::Migration[8.1]
  # 项目未上线：清空全部业务数据后，把学期与年级/科目/年级科目配置从学校改为归属校区
  TABLES_TO_TRUNCATE = %i[
    attendances courses klass_students reservations student_referrals
    semester_klasses grade_subjects semesters guardians students teachers grades subjects
  ].freeze

  def up
    TABLES_TO_TRUNCATE.each { |table| execute "DELETE FROM #{table}" }

    remove_foreign_key :semesters, :schools
    remove_index :semesters, name: "index_semesters_on_school_id_and_seq"
    remove_index :semesters, name: "index_semesters_on_school_id"
    remove_column :semesters, :school_id
    add_column :semesters, :campuse_id, :bigint, null: false
    add_index :semesters, [ :campuse_id, :seq ], unique: true
    add_foreign_key :semesters, :campuses

    remove_foreign_key :grade_subjects, :schools
    remove_index :grade_subjects, name: "index_grade_subjects_on_school_semester_grade_subject"
    remove_index :grade_subjects, name: "index_grade_subjects_on_school_id"
    remove_column :grade_subjects, :school_id
    add_column :grade_subjects, :campuse_id, :bigint, null: false
    add_index :grade_subjects, [ :campuse_id, :semester_id, :grade_id, :subject_id ],
      unique: true, name: "index_grade_subjects_on_campuse_semester_grade_subject"
    add_foreign_key :grade_subjects, :campuses

    add_column :grades, :campuse_id, :bigint, null: false
    add_index :grades, [ :campuse_id, :level ], unique: true
    add_index :grades, [ :campuse_id, :name ], unique: true
    add_foreign_key :grades, :campuses

    add_column :subjects, :campuse_id, :bigint, null: false
    add_index :subjects, [ :campuse_id, :code ], unique: true
    add_index :subjects, [ :campuse_id, :name ], unique: true
    add_foreign_key :subjects, :campuses
  end

  def down
    remove_foreign_key :subjects, :campuses
    remove_column :subjects, :campuse_id

    remove_foreign_key :grades, :campuses
    remove_column :grades, :campuse_id

    remove_foreign_key :grade_subjects, :campuses
    remove_index :grade_subjects, name: "index_grade_subjects_on_campuse_semester_grade_subject"
    remove_column :grade_subjects, :campuse_id
    add_reference :grade_subjects, :school, null: true, foreign_key: true
    add_index :grade_subjects, [ :school_id, :semester_id, :grade_id, :subject_id ],
      unique: true, name: "index_grade_subjects_on_school_semester_grade_subject"

    remove_foreign_key :semesters, :campuses
    remove_column :semesters, :campuse_id
    add_reference :semesters, :school, null: true, foreign_key: true
    add_index :semesters, [ :school_id, :seq ], unique: true
  end
end
