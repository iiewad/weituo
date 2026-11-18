class AttendanceWorkbook
  def initialize(campuse:, semester:)
    @campuse = campuse
    @semester = semester
    @semester_klasses = SemesterKlass.where(campuse_id: campuse.id, semester_id: semester.id)
      .includes(:grade, :subject, :teacher, :courses, klass_students: :student)
      .to_a
      .sort_by { |sk| [ sk.grade.level, sk.subject.name, sk.genre.to_s, sk.seq.to_i ] }

    course_ids = @semester_klasses.flat_map { |sk| sk.courses.map(&:id) }
    @attendances = Attendance.where(course_id: course_ids)
      .index_by { |attendance| [ attendance.course_id, attendance.klass_student_id ] }
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true
    workbook = package.workbook
    styles = AttendanceSheet.build_styles(workbook)

    if @semester_klasses.empty?
      add_empty_sheet(workbook, styles)
    else
      @semester_klasses.group_by(&:grade).sort_by { |grade, _| grade.level }.each do |grade, semester_klasses|
        semester_klasses.each do |semester_klass|
          AttendanceSheet.new(
            semester_klass,
            sheet_name: sheet_name(grade, semester_klass),
            attendances: @attendances
          ).add_to(workbook, styles: styles)
        end
      end
    end

    package.to_stream.read
  end

  private
    def add_empty_sheet(workbook, styles)
      workbook.add_worksheet(name: "考勤表") do |sheet|
        sheet.add_row([ "#{@semester.name} · 考勤表" ], style: styles[:title])
        sheet.merge_cells("A1:H1")
        sheet.add_row([ "当前学期暂无班级" ], style: styles[:cell])
      end
    end

    def sheet_name(grade, semester_klass)
      "#{grade.name}-#{semester_klass.name}".gsub(/[\[\]:*?\/\\]/, "-")[0, 31]
    end
end
