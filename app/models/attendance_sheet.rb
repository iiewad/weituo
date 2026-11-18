class AttendanceSheet
  TITLE_ROW = 1
  INFO_ROW = 2
  LEGEND_ROW = 3
  HEADER_ROW = 4
  DATA_START_ROW = 5

  STATUS_FILLS = {
    "normal" => "DCFCE7",
    "filled" => "DCFCE7",
    "absent" => "FEE2E2",
    "personal_leave" => "FEF3C7",
    "sick_leave" => "FEF3C7",
    "quit" => "E2E8F0",
    "transfer" => "E2E8F0"
  }.freeze

  LEGEND = "√ 正常 · 补 补课 · 缺 缺课 · 事 事假 · 病 病假 · 退 退课 · 转 转出"

  def initialize(semester_klass)
    @semester_klass = semester_klass
    @courses = semester_klass.courses.order(:seq).to_a
    @klass_students = semester_klass.klass_students.includes(:student).to_a
    @active_count = @klass_students.count { |klass_student| klass_student.status == "in" }
    @attendances = Attendance.where(course_id: @courses.map(&:id))
      .index_by { |attendance| [ attendance.course_id, attendance.klass_student_id ] }
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true
    workbook = package.workbook

    styles = build_styles(workbook)

    workbook.add_worksheet(name: sheet_name) do |sheet|
      build_header(sheet, styles)
      build_rows(sheet, styles)
      decorate(sheet)
    end

    package.to_stream.read
  end

  private
    def build_styles(workbook)
      styles = workbook.styles

      {
        title: styles.add_style(sz: 14, b: true, alignment: { vertical: :center }),
        label: styles.add_style(b: true, fg_color: "475569"),
        value: styles.add_style({}),
        header: styles.add_style(
          b: true,
          bg_color: "F1F5F9",
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          border: { style: :thin, color: "CBD5E1" }
        ),
        name: styles.add_style(alignment: { horizontal: :left }),
        cell: styles.add_style(alignment: { horizontal: :center }),
        muted: styles.add_style(fg_color: "94A3B8", alignment: { horizontal: :center }),
        legend: styles.add_style(fg_color: "64748B", sz: 9),
        status: STATUS_FILLS.transform_values { |fill|
          styles.add_style(bg_color: fill, alignment: { horizontal: :center })
        }
      }
    end

    def build_header(sheet, styles)
      sheet.add_row([ "#{@semester_klass.name} · 考勤表" ], style: styles[:title])
      sheet.merge_cells("A#{TITLE_ROW}:#{last_column}#{TITLE_ROW}")

      info = [
        "学期", @semester_klass.semester.name,
        "校区", @semester_klass.campuse.name,
        "教师", "#{@semester_klass.teacher.name} 老师",
        "班型", SemesterKlass::GENRE_MAP_REVERSE[@semester_klass.genre],
        "在班", "#{@active_count} 人"
      ]
      sheet.add_row(info, style: [ styles[:label], styles[:value] ] * 5)

      sheet.add_row([ LEGEND ], style: styles[:legend])
      sheet.merge_cells("A#{LEGEND_ROW}:#{last_column}#{LEGEND_ROW}")

      headers = [ "学员" ] + @courses.map { |course| course_header(course) }
      sheet.add_row(headers, style: styles[:header])
    end

    def build_rows(sheet, styles)
      @klass_students.each do |klass_student|
        values = [ klass_student.student.name ]
        cell_styles = [ styles[:name] ]

        @courses.each do |course|
          attendance = @attendances[[ course.id, klass_student.id ]]

          if course.started?
            if attendance
              values << attendance.status_label
              cell_styles << (styles[:status][attendance.status] || styles[:cell])
            else
              values << "—"
              cell_styles << styles[:cell]
            end
          else
            values << "未开"
            cell_styles << styles[:muted]
          end
        end

        sheet.add_row(values, style: cell_styles)
      end
    end

    def decorate(sheet)
      sheet.sheet_view.show_grid_lines = false
      sheet.sheet_view.pane do |pane|
        pane.state = :frozen
        pane.top_left_cell = "B#{DATA_START_ROW}"
        pane.x_split = 1
        pane.y_split = HEADER_ROW
        pane.active_pane = :bottom_right
      end
      sheet.column_widths(18, *Array.new(@courses.size, 9))

      return if @klass_students.empty?

      data_end_row = DATA_START_ROW + @klass_students.size - 1
      sheet.auto_filter = "A#{HEADER_ROW}:#{last_column}#{data_end_row}"
    end

    def course_header(course)
      state = course.start_date ? course.start_date.strftime("%m-%d") : "未开"
      "第#{course.seq}课\n#{state}"
    end

    def last_column
      Axlsx.col_ref(1 + @courses.size - 1)
    end

    def sheet_name
      "#{@semester_klass.name} 考勤".gsub(/[\[\]:*?\/\\]/, "-")[0, 31]
    end
end
