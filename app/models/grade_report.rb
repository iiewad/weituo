class GradeReport
  Entry = Struct.new(:name, :detail, keyword_init: true)
  RosterEntry = Struct.new(:name, :tags, keyword_init: true)

  Row = Struct.new(
    :semester, :grade, :active_count, :new_count, :expand_count, :return_count,
    :active_students, :new_students, :expand_students, :return_students,
    keyword_init: true
  ) do
    def new_rate
      rate(new_count)
    end

    def expand_rate
      rate(expand_count)
    end

    def return_rate
      rate(return_count)
    end

    private
      def rate(count)
        active_count.to_i.zero? ? 0.0 : (count.to_f / active_count).round(2)
      end
  end

  TAG_ORDER = { "新增" => 0, "回流" => 1, "拓科" => 2, "延续" => 3 }.freeze

  def initialize(campuse:, grade_ids:, semester_id: nil)
    @campuse = campuse
    @grade_ids = grade_ids
    @semester_filter = semester_id&.to_i
    @semesters = Semester.where(school_id: campuse.school_id).to_a.sort_by(&:seq)
    @semesters_by_id = @semesters.index_by(&:id)
    build_semester_index
  end

  def rows
    @rows ||= begin
      load_student_data
      build_rows
    end
  end

  # [[semester, 该学期各行, 小计行], ...]，学期按 seq 倒序
  def semester_groups
    @semester_groups ||= rows.group_by(&:semester).map { |semester, group_rows|
      [ semester, group_rows, totals_row(semester, group_rows) ]
    }
  end

  def summary
    {
      semester_count: semester_groups.size,
      active_count: rows.sum(&:active_count),
      new_count: rows.sum(&:new_count),
      expand_count: rows.sum(&:expand_count),
      return_count: rows.sum(&:return_count)
    }
  end

  private
    def build_semester_index
      @history_semester_ids = {}
      @previous_semester_id = {}

      @semesters.each do |semester|
        earlier = @semesters.select { |other| other.seq < semester.seq }
        @history_semester_ids[semester.id] = earlier.map(&:id)
        @previous_semester_id[semester.id] = earlier.max_by(&:seq)&.id
      end
    end

    # 一次取回本校区所有在班报名：历史判定需要跨年级数据，行展示再按授权年级过滤
    def load_student_data
      @semester_grade_students = Hash.new { |hash, key| hash[key] = [] }
      @semester_students = Hash.new { |hash, key| hash[key] = Set.new }
      @student_semester_subjects = Hash.new { |hash, key| hash[key] = Set.new }

      KlassStudent.active.joins(:semester_klass)
        .where(semester_klasses: { campuse_id: @campuse.id }, status: "in")
        .pluck(
          "semester_klasses.semester_id",
          "semester_klasses.grade_id",
          "semester_klasses.subject_id",
          "klass_students.student_id"
        ).each do |semester_id, grade_id, subject_id, student_id|
          @semester_grade_students[[ semester_id, grade_id ]] << student_id
          @semester_students[semester_id] << student_id
          @student_semester_subjects[[ semester_id, student_id ]] << subject_id
        end

      @grades_by_id = Grade.where(id: @grade_ids).index_by(&:id)
      @student_info = Student.where(id: @semester_students.each_value.flat_map(&:to_a).uniq)
        .includes(:day_school)
        .index_by(&:id)
      @subject_names = Subject.pluck(:id, :name).to_h
    end

    def build_rows
      target_semesters = @semesters.select { |semester|
        @semester_filter.nil? || semester.id == @semester_filter
      }.sort_by { |semester| -semester.seq }

      target_semesters.flat_map { |semester|
        grade_ids = @semester_grade_students.keys.filter_map { |(semester_id, grade_id)|
          grade_id if semester_id == semester.id && @grades_by_id.key?(grade_id)
        }.uniq
        grade_ids.sort_by { |grade_id| @grades_by_id[grade_id].level }
          .map { |grade_id| build_row(semester, @grades_by_id[grade_id]) }
      }
    end

    def build_row(semester, grade)
      cohort_ids = @semester_grade_students[[ semester.id, grade.id ]].uniq
      history_ids = @history_semester_ids[semester.id].reduce(Set.new) { |acc, id|
        acc.merge(@semester_students[id])
      }
      previous_id = @previous_semester_id[semester.id]
      previous_ids = previous_id ? @semester_students[previous_id] : Set.new

      new_ids = []
      return_ids = []
      expand_ids = []

      cohort_ids.each do |student_id|
        if !history_ids.include?(student_id)
          new_ids << student_id
        elsif !previous_ids.include?(student_id)
          return_ids << student_id
        elsif expand?(student_id, semester.id, previous_id)
          expand_ids << student_id
        end
      end

      Row.new(
        semester:,
        grade:,
        active_count: cohort_ids.size,
        new_count: new_ids.size,
        expand_count: expand_ids.size,
        return_count: return_ids.size,
        active_students: roster_entries(cohort_ids, new_ids, expand_ids, return_ids),
        new_students: new_entries(new_ids),
        expand_students: expand_entries(expand_ids, semester.id, previous_id),
        return_students: return_entries(return_ids, semester.id, previous_id)
      )
    end

    # 拓科：延续上学期至少一个科目，且本学期出现上学期没学过的科目（只换科不算）
    def expand?(student_id, semester_id, previous_id)
      previous_subjects = @student_semester_subjects[[ previous_id, student_id ]]
      current_subjects = @student_semester_subjects[[ semester_id, student_id ]]
      (current_subjects - previous_subjects).any? && (current_subjects & previous_subjects).any?
    end

    def totals_row(semester, group_rows)
      Row.new(
        semester:,
        grade: nil,
        active_count: group_rows.sum(&:active_count),
        new_count: group_rows.sum(&:new_count),
        expand_count: group_rows.sum(&:expand_count),
        return_count: group_rows.sum(&:return_count),
        active_students: [], new_students: [], expand_students: [], return_students: []
      )
    end

    def roster_entries(ids, new_ids, expand_ids, return_ids)
      entries = ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        tags = [ tag_for(id, new_ids, expand_ids, return_ids) ]
        RosterEntry.new(name: student.identity_label, tags:)
      }

      entries.sort_by { |entry| [ TAG_ORDER.fetch(entry.tags.first, 9), entry.name ] }
    end

    def tag_for(id, new_ids, expand_ids, return_ids)
      return "新增" if new_ids.include?(id)
      return "拓科" if expand_ids.include?(id)
      return "回流" if return_ids.include?(id)

      "延续"
    end

    def new_entries(ids)
      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        detail = [
          student.in_date ? "入学 #{student.in_date.strftime("%Y-%m-%d")}" : nil,
          student.day_school&.name,
          "历史学期无入班记录"
        ].compact.join(" · ")

        Entry.new(name: student.identity_label, detail:)
      }.sort_by(&:name)
    end

    def expand_entries(ids, semester_id, previous_id)
      previous_name = @semesters_by_id[previous_id]&.name

      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        previous_subjects = @student_semester_subjects[[ previous_id, id ]]
        current_subjects = @student_semester_subjects[[ semester_id, id ]]
        added = subject_labels(current_subjects - previous_subjects)
        continued = subject_labels(current_subjects & previous_subjects)

        detail = [
          "上学期（#{previous_name}）：#{subject_labels(previous_subjects).join("、")}",
          "延续：#{continued.join("、")}",
          "新增科目：#{added.join("、")}"
        ].join(" · ")

        Entry.new(name: student.identity_label, detail:)
      }.sort_by(&:name)
    end

    def return_entries(ids, semester_id, previous_id)
      previous_name = @semesters_by_id[previous_id]&.name

      ids.filter_map { |id|
        student = @student_info[id]
        next unless student

        latest = @history_semester_ids[semester_id]
          .map { |sid| @semesters_by_id[sid] }
          .compact
          .select { |semester| @semester_students[semester.id].include?(id) }
          .max_by(&:seq)

        detail = if latest
          subjects = subject_labels(@student_semester_subjects[[ latest.id, id ]]).join("、")
          "上学期（#{previous_name}）未入班 · 最近入班：#{latest.name}（#{subjects}）"
        else
          "上学期（#{previous_name}）未入班"
        end

        Entry.new(name: student.identity_label, detail:)
      }.sort_by(&:name)
    end

    def subject_labels(subject_ids)
      subject_ids.map { |id| @subject_names[id] || "未知科目" }
    end
end
