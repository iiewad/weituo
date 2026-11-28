class ReplaceStudentInDateWithInSemester < ActiveRecord::Migration[8.1]
  def up
    add_reference :students, :in_semester, foreign_key: { to_table: :semesters, on_delete: :nullify }
    Student.reset_column_information

    # 回填入学学期：取学员全部入班记录（含已移出）中 seq 最早的学期；无入班记录的留空
    Student.includes(all_klass_students: { semester_klass: :semester }).find_each do |student|
      semester = student.all_klass_students
        .filter_map { |ks| ks.semester_klass&.semester }
        .min_by { |s| s.seq.to_i }
      student.update_column(:in_semester_id, semester.id) if semester
    end

    remove_column :students, :in_date
  end

  def down
    add_column :students, :in_date, :date
    remove_reference :students, :in_semester, foreign_key: { to_table: :semesters }
  end
end
