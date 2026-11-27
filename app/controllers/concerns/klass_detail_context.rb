# 班级考勤矩阵的行渲染上下文：show 与考勤行流式替换共用，调用前需先设置 @sk。
module KlassDetailContext
  extend ActiveSupport::Concern

  private
    def set_klass_row_context
      @klass_students = @sk.klass_students.includes(:student).to_a
      @courses = @sk.courses.order(:seq).to_a
      @attendance_by_cell = Attendance.where(
        course_id: @courses.map(&:id),
        klass_student_id: @klass_students.map(&:id)
      ).includes(:marked_by).index_by { |attendance| [ attendance.course_id, attendance.klass_student_id ] }
      @next_semester = @sk.semester.related_next_semester
      @reserved_student_ids = @sk.reserve_students.map(&:id)
      @reservations_by_student_id = if @next_semester
        Reservation.where(semester_id: @next_semester.id, subject_id: @sk.subject_id, student_id: @klass_students.map(&:student_id))
          .includes(:student, :grade, :teacher, :semester_klass).index_by(&:student_id)
      else
        {}
      end
      @placed_student_ids = @sk.next_semester_placed_student_ids
      @reserve_grade_ids = reserve_grade_ids
      @reserve_grades = Grade.where(id: @reserve_grade_ids).order(:level).to_a
      @reserve_default_grade = @reserve_grades.find { |grade| grade.level == @sk.grade.level + 1 } || @sk.grade
      @reserve_teachers = @sk.campuse.teachers.active.where(subject_id: @sk.subject_id).order(:name).to_a
      @transfer_target_klasses = @sk.semester.semester_klasses
        .where(campuse_id: @sk.campuse_id, grade_id: @sk.grade_id)
        .where.not(id: @sk.id)
        .includes(:subject, :teacher)
        .to_a
        .sort_by(&:display_order_key)
      transfer_target_ids = @transfer_target_klasses.map(&:id)
      @transfer_target_counts = KlassStudent.active.where(
        semester_klass_id: transfer_target_ids, status: "in"
      ).group(:semester_klass_id).count
      # 学员已加入的目标班：转出抽屉按学员动态隐藏，避免重复转入
      @enrolled_target_ids_by_student = KlassStudent
        .active
        .where(semester_klass_id: transfer_target_ids)
        .pluck(:student_id, :semester_klass_id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last) }
    end

    def reserve_grade_ids
      ids = [ @sk.grade_id ]
      next_grade = Grade.find_by(level: @sk.grade.level + 1)
      ids << next_grade.id if next_grade
      ids
    end
end
