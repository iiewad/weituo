class StatementReport
  Entry = Struct.new(:name, :detail, keyword_init: true)
  RosterEntry = Struct.new(:name, :tags, keyword_init: true)

  Row = Struct.new(
    :semester_klass, :active_count, :reserve_count, :unreserved_count,
    :active_students, :reserve_students, :unreserved_students,
    keyword_init: true
  ) do
    def reserve_rate
      rate(reserve_count)
    end

    def unreserved_rate
      rate(unreserved_count)
    end

    private
      def rate(count)
        active_count.zero? ? 0.0 : (count.to_f / active_count).round(2)
      end
  end

  def initialize(semester_klasses, campuse:, reserve_min_attendances: nil)
    @semester_klasses = semester_klasses.to_a
    @campuse = campuse
    @reserve_min_attendances = (reserve_min_attendances || campuse.reserve_min_attendances).to_i
    @semesters = Semester.where(school_id: campuse.school_id).to_a
    @semesters_by_id = @semesters.index_by(&:id)
    build_semester_index
  end

  def rows
    @rows ||= begin
      load_student_data
      @semester_klasses.map { |semester_klass| build_row(semester_klass) }
    end
  end

  def summary
    current_rows = rows
    {
      class_count: current_rows.size,
      active_count: current_rows.sum(&:active_count),
      reserve_rate: average(current_rows, :reserve_rate)
    }
  end

  private
    def average(rows, method)
      return 0.0 if rows.empty?

      (rows.sum { |row| row.public_send(method) } / rows.size * 100).round(1)
    end

    def build_semester_index
      @next_semester_ids = {}

      @semesters.each do |semester|
        @next_semester_ids[semester.id] = @semesters.select { |other|
          other.seq > semester.seq
        }.min_by(&:seq)&.id
      end
    end

    # 一次取回本校区所有在班报名，避免逐班级查询学员与历史数据
    def load_student_data
      @active_student_ids = Hash.new { |hash, key| hash[key] = [] }
      @semester_subject_student_ids = Hash.new { |hash, key| hash[key] = [] }
      @student_semester_subject_classes = Hash.new { |hash, key| hash[key] = [] }
      @class_details = SemesterKlass.where(campuse_id: @campuse.id)
        .includes(:grade, :subject, :teacher)
        .index_by(&:id)

      KlassStudent.active.joins(:semester_klass)
        .where(semester_klasses: { campuse_id: @campuse.id }, status: "in")
        .pluck(
          "semester_klasses.semester_id",
          "semester_klasses.subject_id",
          "klass_students.semester_klass_id",
          "klass_students.student_id"
        ).each do |semester_id, subject_id, semester_klass_id, student_id|
          @active_student_ids[semester_klass_id] << student_id
          @semester_subject_student_ids[[ semester_id, subject_id ]] << student_id
          @student_semester_subject_classes[[ semester_id, subject_id, student_id ]] << semester_klass_id
        end

      @student_info = Student.where(id: @active_student_ids.values.flatten.uniq)
        .includes(:day_school)
        .index_by(&:id)

      # 下学期同科目班的实际出勤次数，用于「至少上课 N 次才计入预留」
      class_ids = @student_semester_subject_classes.values.flatten.uniq
      @study_counts = Attendance
        .joins(:klass_student)
        .where(status: %w[normal filled], klass_students: { semester_klass_id: class_ids })
        .group("klass_students.semester_klass_id", "klass_students.student_id")
        .count

      # 已登记预留表、但尚未排入下学期班级的学员：未预留原因要区分「未报」与「待分班」
      @reserved_keys = Reservation.where(student_id: @student_info.keys)
        .pluck(:semester_id, :subject_id, :student_id).to_set
    end

    def study_count(student_id, semester_id, subject_id)
      return 0 if semester_id.blank?

      @student_semester_subject_classes[[ semester_id, subject_id, student_id ]]
        .uniq
        .sum { |class_id| @study_counts[[ class_id, student_id ]].to_i }
    end

    def build_row(semester_klass)
      active_ids = @active_student_ids[semester_klass.id].uniq

      next_semester_id = @next_semester_ids[semester_klass.semester_id]
      next_subject_ids = next_semester_id ? @semester_subject_student_ids[[ next_semester_id, semester_klass.subject_id ]].uniq : []
      reserve_ids = (active_ids & next_subject_ids).select do |student_id|
        study_count(student_id, next_semester_id, semester_klass.subject_id) >= @reserve_min_attendances
      end
      unreserved_ids = active_ids - reserve_ids

      Row.new(
        semester_klass:,
        active_count: active_ids.size,
        reserve_count: reserve_ids.size,
        unreserved_count: unreserved_ids.size,
        active_students: roster_entries(active_ids, reserve_ids),
        reserve_students: reserve_entries(reserve_ids, next_semester_id, semester_klass.subject_id),
        unreserved_students: unreserved_entries(unreserved_ids, next_semester_id, semester_klass.subject_id)
      )
    end

    # 在班名单附带该学员在本班的预留标签，便于对照
    def roster_entries(ids, reserve_ids)
      entries = ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        tags = [ reserve_ids.include?(id) ? "预留" : "未预留" ]

        RosterEntry.new(name: student.identity_label, tags:)
      }

      # 未预留学员排在名单前面，便于一眼看到需要跟进的学员
      entries.sort_by { |entry| [ entry.tags.include?("未预留") ? 0 : 1, entry.name ] }
    end

    def unreserved_entries(ids, next_semester_id, subject_id)
      next_semester = @semesters_by_id[next_semester_id]

      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        enrolled_next = @student_semester_subject_classes[[ next_semester_id, subject_id, id ]].present?
        detail = if next_semester_id.blank?
          "暂无下学期"
        elsif enrolled_next
          "下学期同科目班已上 #{study_count(id, next_semester_id, subject_id)} 次，未达 #{@reserve_min_attendances} 次"
        elsif @reserved_keys.include?([ next_semester_id, subject_id, id ])
          "已登记预留，待分班"
        else
          "下学期（#{next_semester&.name}）未报同科目"
        end

        Entry.new(name: student.identity_label, detail:)
      }.sort_by(&:name)
    end

    def reserve_entries(ids, next_semester_id, subject_id)
      next_semester = @semesters_by_id[next_semester_id]

      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        class_ids = @student_semester_subject_classes[[ next_semester_id, subject_id, id ]].uniq
        labels = class_ids.map { |class_id|
          semester_klass = @class_details[class_id]
          "#{semester_klass.name}(#{semester_klass.teacher.name})"
        }.uniq

        detail = if labels.any?
          "下学期（#{next_semester&.name}）：#{labels.join("、")} · 已上 #{study_count(id, next_semester_id, subject_id)} 次"
        else
          "下学期暂无同科目班级"
        end

        Entry.new(name: student.identity_label, detail:)
      }.sort_by(&:name)
    end
end
