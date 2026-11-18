class StatementReport
  Entry = Struct.new(:name, :detail, keyword_init: true)

  Row = Struct.new(
    :semester_klass, :active_count, :new_count, :expand_count, :reserve_count,
    :active_students, :new_students, :expand_students, :reserve_students,
    keyword_init: true
  ) do
    def new_rate
      rate(new_count)
    end

    def expand_rate
      rate(expand_count)
    end

    def reserve_rate
      rate(reserve_count)
    end

    private
      def rate(count)
        active_count.zero? ? 0.0 : (count.to_f / active_count).round(2)
      end
  end

  def initialize(semester_klasses, campuse:)
    @semester_klasses = semester_klasses.to_a
    @campuse = campuse
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
      new_rate: average(current_rows, :new_rate),
      expand_rate: average(current_rows, :expand_rate),
      reserve_rate: average(current_rows, :reserve_rate)
    }
  end

  private
    def average(rows, method)
      return 0.0 if rows.empty?

      (rows.sum { |row| row.public_send(method) } / rows.size * 100).round(1)
    end

    def build_semester_index
      @history_semester_ids = {}
      @previous_semester_ids = {}
      @next_semester_ids = {}

      @semesters.each do |semester|
        @history_semester_ids[semester.id] = @semesters.select { |other|
          other.seq < semester.seq && other.start_date < semester.start_date
        }.map(&:id)
        @previous_semester_ids[semester.id] = @semesters.select { |other|
          other.seq < semester.seq && other.end_date <= semester.start_date
        }.max_by(&:seq)&.id
        @next_semester_ids[semester.id] = @semesters.select { |other|
          other.seq > semester.seq && other.start_date >= semester.end_date
        }.min_by(&:seq)&.id
      end
    end

    # 一次取回本校区所有在班报名，避免逐班级查询学员与历史数据
    def load_student_data
      @active_student_ids = Hash.new { |hash, key| hash[key] = [] }
      @semester_student_ids = Hash.new { |hash, key| hash[key] = [] }
      @semester_subject_student_ids = Hash.new { |hash, key| hash[key] = [] }
      @student_semester_classes = Hash.new { |hash, key| hash[key] = [] }
      @student_semester_subject_classes = Hash.new { |hash, key| hash[key] = [] }
      @class_details = SemesterKlass.where(campuse_id: @campuse.id)
        .includes(:grade, :subject, :teacher)
        .index_by(&:id)

      KlassStudent.joins(:semester_klass)
        .where(semester_klasses: { campuse_id: @campuse.id }, status: "in")
        .pluck(
          "semester_klasses.semester_id",
          "semester_klasses.subject_id",
          "klass_students.semester_klass_id",
          "klass_students.student_id"
        ).each do |semester_id, subject_id, semester_klass_id, student_id|
          @active_student_ids[semester_klass_id] << student_id
          @semester_student_ids[semester_id] << student_id
          @semester_subject_student_ids[[ semester_id, subject_id ]] << student_id
          @student_semester_classes[[ semester_id, student_id ]] << semester_klass_id
          @student_semester_subject_classes[[ semester_id, subject_id, student_id ]] << semester_klass_id
        end

      @student_info = Student.where(id: @active_student_ids.values.flatten.uniq)
        .includes(:day_school)
        .index_by(&:id)
    end

    def build_row(semester_klass)
      active_ids = @active_student_ids[semester_klass.id].uniq
      history_ids = @history_semester_ids[semester_klass.semester_id]
        .flat_map { |id| @semester_student_ids[id] }.uniq
      new_ids = active_ids - history_ids

      previous_semester_id = @previous_semester_ids[semester_klass.semester_id]
      previous_all_ids = previous_semester_id ? @semester_student_ids[previous_semester_id].uniq : []
      previous_subject_ids = previous_semester_id ? @semester_subject_student_ids[[ previous_semester_id, semester_klass.subject_id ]].uniq : []
      expand_ids = (active_ids & previous_all_ids) - previous_subject_ids

      next_semester_id = @next_semester_ids[semester_klass.semester_id]
      next_subject_ids = next_semester_id ? @semester_subject_student_ids[[ next_semester_id, semester_klass.subject_id ]].uniq : []
      reserve_ids = active_ids & next_subject_ids

      Row.new(
        semester_klass:,
        active_count: active_ids.size,
        new_count: new_ids.size,
        expand_count: expand_ids.size,
        reserve_count: reserve_ids.size,
        active_students: student_names(active_ids),
        new_students: new_entries(new_ids),
        expand_students: expand_entries(expand_ids, previous_semester_id, semester_klass.subject_id),
        reserve_students: reserve_entries(reserve_ids, next_semester_id, semester_klass.subject_id)
      )
    end

    def student_names(ids)
      ids.map { |id| @student_info[id]&.name }.compact.sort
    end

    def new_entries(ids)
      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        detail = [
          student.in_date ? "入学 #{student.in_date.strftime("%Y-%m-%d")}" : nil,
          student.day_school&.name,
          "历史学期无记录"
        ].compact.join(" · ")

        Entry.new(name: student.name, detail:)
      }.sort_by(&:name)
    end

    def expand_entries(ids, previous_semester_id, subject_id)
      previous_semester = @semesters_by_id[previous_semester_id]

      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        class_ids = @student_semester_classes[[ previous_semester_id, id ]].uniq -
          @student_semester_subject_classes[[ previous_semester_id, subject_id, id ]].uniq
        labels = class_ids.map { |class_id|
          semester_klass = @class_details[class_id]
          "#{semester_klass.subject.name}(#{semester_klass.teacher.name})"
        }.uniq

        detail = if labels.any?
          "上学期（#{previous_semester&.name}）：#{labels.join("、")}"
        else
          "上学期没有其他科目记录"
        end

        Entry.new(name: student.name, detail:)
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
          "下学期（#{next_semester&.name}）：#{labels.join("、")}"
        else
          "下学期暂无同科目班级"
        end

        Entry.new(name: student.name, detail:)
      }.sort_by(&:name)
    end
end
