class StatementSheet
  HEADER_ROW = 4
  DATA_START_ROW = 5

  HEADERS = %w[学期 年级 科目 教师 班型 班级 在班 预留 预留率(%)]

  DETAIL_HEADER_ROW = 3
  DETAIL_DATA_START_ROW = 4
  DETAIL_HEADERS = %w[学期 年级 班级 科目 教师 类型 学员 说明]

  def initialize(rows:, summary:, campuse:, semester:, filter_summary:)
    @rows = rows
    @summary = summary
    @campuse = campuse
    @semester = semester
    @filter_summary = filter_summary
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true
    workbook = package.workbook
    styles = build_styles(workbook)

    workbook.add_worksheet(name: "班级预留报表") do |sheet|
      build_header(sheet, styles)
      build_rows(sheet, styles)
      decorate(sheet)
    end

    workbook.add_worksheet(name: "学员明细") do |sheet|
      build_detail_header(sheet, styles)
      build_detail_rows(sheet, styles)
      decorate_detail(sheet)
    end

    package.to_stream.read
  end

  private
    def build_styles(workbook)
      styles = workbook.styles

      {
        title: styles.add_style(sz: 14, b: true, alignment: { vertical: :center }, **XlsxStyle::BORDER),
        label: styles.add_style(b: true, fg_color: "475569", **XlsxStyle::BORDER),
        value: styles.add_style(**XlsxStyle::BORDER),
        header: styles.add_style(
          b: true,
          bg_color: "F1F5F9",
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          **XlsxStyle::BORDER
        ),
        name: styles.add_style(alignment: { horizontal: :left }, **XlsxStyle::BORDER),
        cell: styles.add_style(alignment: { horizontal: :center }, **XlsxStyle::BORDER)
      }
    end

    def build_header(sheet, styles)
      XlsxStyle.merged_row(sheet, "#{@semester.name} · 班级预留报表", styles[:title], HEADERS.size)

      info = [
        "校区", @campuse.name,
        "班级", "#{@summary[:class_count]} 个",
        "在班", "#{@summary[:active_count]} 人次",
        "平均预留", "#{@summary[:reserve_rate]}%"
      ]
      XlsxStyle.full_row(sheet, info, [ styles[:label], styles[:value] ] * 4, HEADERS.size)

      XlsxStyle.merged_row(sheet, "筛选条件：#{@filter_summary}", styles[:value], HEADERS.size)

      sheet.add_row(HEADERS, style: styles[:header])
    end

    def build_rows(sheet, styles)
      if @rows.empty?
        XlsxStyle.merged_row(sheet, "当前筛选条件下没有班级数据", styles[:cell], HEADERS.size)
        return
      end

      @rows.each do |row|
        sk = row.semester_klass
        sheet.add_row(
          [
            sk.semester.name,
            sk.grade.name,
            sk.subject.name,
            "#{sk.teacher.name} 老师",
            SemesterKlass::GENRE_MAP_REVERSE[sk.genre],
            sk.name,
            row.active_count,
            row.reserve_count,
            (row.reserve_rate * 100).round(1)
          ],
          style: [
            styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell],
            styles[:name], styles[:cell], styles[:cell], styles[:cell]
          ]
        )
      end
    end

    def build_detail_header(sheet, styles)
      XlsxStyle.merged_row(sheet, "预留学员明细", styles[:title], DETAIL_HEADERS.size)

      XlsxStyle.merged_row(sheet, "筛选条件：#{@filter_summary}", styles[:value], DETAIL_HEADERS.size)

      sheet.add_row(DETAIL_HEADERS, style: styles[:header])
    end

    def build_detail_rows(sheet, styles)
      detail_rows = []

      @rows.each do |row|
        sk = row.semester_klass
        [
          [ "预留", row.reserve_students ]
        ].each do |type, entries|
          entries.each do |entry|
            detail_rows << [
              sk.semester.name,
              sk.grade.name,
              sk.name,
              sk.subject.name,
              "#{sk.teacher.name} 老师",
              type,
              entry.name,
              entry.detail
            ]
          end
        end
      end

      if detail_rows.empty?
        XlsxStyle.merged_row(sheet, "当前筛选条件下没有学员明细", styles[:cell], DETAIL_HEADERS.size)
        return
      end

      detail_rows.each do |values|
        sheet.add_row(
          values,
          style: [ styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:name] ]
        )
      end
    end

    def decorate_detail(sheet)
      sheet.sheet_view.show_grid_lines = false
      sheet.sheet_view.pane do |pane|
        pane.state = :frozen
        pane.top_left_cell = "A#{DETAIL_DATA_START_ROW}"
        pane.y_split = DETAIL_HEADER_ROW
        pane.active_pane = :bottom_left
      end
      sheet.column_widths(16, 10, 14, 10, 10, 8, 14, 48)

      detail_row_count = @rows.sum { |row| row.reserve_students.size }
      return if detail_row_count.zero?

      data_end_row = DETAIL_DATA_START_ROW + detail_row_count - 1
      sheet.auto_filter = "A#{DETAIL_HEADER_ROW}:#{detail_last_column}#{data_end_row}"
    end

    def detail_last_column
      Axlsx.col_ref(DETAIL_HEADERS.size - 1)
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
      sheet.column_widths(16, 10, 10, 10, 10, 14, 8, 8, 10)

      return if @rows.empty?

      data_end_row = DATA_START_ROW + @rows.size - 1
      sheet.auto_filter = "A#{HEADER_ROW}:#{last_column}#{data_end_row}"
    end

    def last_column
      Axlsx.col_ref(HEADERS.size - 1)
    end
end
