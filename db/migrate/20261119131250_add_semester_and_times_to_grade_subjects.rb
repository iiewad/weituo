class AddSemesterAndTimesToGradeSubjects < ActiveRecord::Migration[8.1]
  def up
    add_reference :grade_subjects, :semester, foreign_key: true, index: true
    add_column :grade_subjects, :times, :integer, null: false, default: 16

    # 历史数据归入各学校当前学期；没有进行中的学期时取 seq 最大的学期
    execute <<~SQL
      UPDATE grade_subjects gs
      JOIN (
        SELECT s.id AS school_id,
          COALESCE(
            (SELECT se.id FROM semesters se
              WHERE se.school_id = s.id AND se.start_date <= CURRENT_DATE AND se.end_date >= CURRENT_DATE
              ORDER BY se.seq DESC, se.id DESC LIMIT 1),
            (SELECT se.id FROM semesters se
              WHERE se.school_id = s.id
              ORDER BY se.seq DESC, se.id DESC LIMIT 1)
          ) AS semester_id
        FROM schools s
      ) picked ON picked.school_id = gs.school_id
      SET gs.semester_id = picked.semester_id
      WHERE gs.semester_id IS NULL
    SQL

    # 没有任何学期的学校无法再维护年级科目，清理无法归属的残留
    execute "DELETE FROM grade_subjects WHERE semester_id IS NULL"
    change_column_null :grade_subjects, :semester_id, false

    remove_index :grade_subjects, name: "index_grade_subjects_on_school_id_and_grade_id_and_subject_id"
    add_index :grade_subjects, [ :school_id, :semester_id, :grade_id, :subject_id ],
      unique: true, name: "index_grade_subjects_on_school_semester_grade_subject"
  end

  def down
    remove_index :grade_subjects, name: "index_grade_subjects_on_school_semester_grade_subject"
    add_index :grade_subjects, [ :school_id, :grade_id, :subject_id ],
      unique: true, name: "index_grade_subjects_on_school_id_and_grade_id_and_subject_id"
    remove_column :grade_subjects, :times
    remove_reference :grade_subjects, :semester, foreign_key: true
  end
end
