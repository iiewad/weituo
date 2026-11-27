class GradeReportSheet
  HEADER_ROW = 4
  DATA_START_ROW = 5

  HEADERS = %w[学期 年级 在班 新增 新增率(%) 拓科 拓科率(%) 回流 回流率(%)]

  DETAIL_HEADER_ROW = 3
  DETAIL_DATA_START_ROW = 4
  DETAIL_HEADERS = %w[学期 年级 类型 学员 说明]

  def initialize(rows:, summary:, campuse:, filter_summary:)
    @rows = rows
    @summary = summary
    @campuse = campuse
    @filter_summary = filter_summary
    @data_row_count = 0
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true
    workbook = package.workbook
    styles = build_styles(workbook)

    workbook.add_worksheet(name: "年级报表") do |sheet|
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
        subtotal: styles.add_style(
          b: true,
          bg_color: "F8FAFC",
          alignment: { horizontal: :center },
          **XlsxStyle::BORDER
        ),
        name: styles.add_style(alignment: { horizontal: :left }, **XlsxStyle::BORDER),
        cell: styles.add_style(alignment: { horizontal: :center }, **XlsxStyle::BORDER)
      }
    end

    def build_header(sheet, styles)
      XlsxStyle.merged_row(sheet, "#{@campuse.name} · 年级报表", styles[:title], HEADERS.size)

      info = [
        "校区", @campuse.name,
        "覆盖学期", "#{@summary[:semester_count]} 个",
        "在班", "#{@summary[:active_count]} 人次",
        "新增 / 拓科 / 回流",
        "#{@summary[:new_count]} / #{@summary[:expand_count]} / #{@summary[:return_count]} 人次"
      ]
      XlsxStyle.full_row(sheet, info, [ styles[:label], styles[:value] ] * 4, HEADERS.size)

      XlsxStyle.merged_row(sheet, "筛选条件：#{@filter_summary}", styles[:value], HEADERS.size)

      sheet.add_row(HEADERS, style: styles[:header])
    end

    def build_rows(sheet, styles)
      if @rows.empty?
        XlsxStyle.merged_row(sheet, "当前筛选条件下没有年级数据", styles[:cell], HEADERS.size)
        return
      end

      @rows.group_by(&:semester).each do |semester, group_rows|
        group_rows.each do |row|
          @data_row_count += 1
          sheet.add_row(
            [
              semester.name,
              row.grade.name,
              row.active_count,
              row.new_count,
              (row.new_rate * 100).round(1),
              row.expand_count,
              (row.expand_rate * 100).round(1),
              row.return_count,
              (row.return_rate * 100).round(1)
            ],
            style: [
              styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:cell],
              styles[:cell], styles[:cell], styles[:cell], styles[:cell]
            ]
          )
        end

        @data_row_count += 1
        sheet.add_row(
          [
            semester.name, "小计",
            group_rows.sum(&:active_count),
            group_rows.sum(&:new_count), "",
            group_rows.sum(&:expand_count), "",
            group_rows.sum(&:return_count), ""
          ],
          style: Array.new(HEADERS.size, styles[:subtotal])
        )
      end
    end

    def build_detail_header(sheet, styles)
      XlsxStyle.merged_row(sheet, "新增 / 拓科 / 回留学员明细", styles[:title], DETAIL_HEADERS.size)

      XlsxStyle.merged_row(sheet, "筛选条件：#{@filter_summary}", styles[:value], DETAIL_HEADERS.size)

      sheet.add_row(DETAIL_HEADERS, style: styles[:header])
    end

    def build_detail_rows(sheet, styles)
      detail_rows = []

      @rows.each do |row|
        [
          [ "新增", row.new_students ],
          [ "拓科", row.expand_students ],
          [ "回流", row.return_students ]
        ].each do |type, entries|
          entries.each do |entry|
            detail_rows << [
              row.semester.name,
              row.grade.name,
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
          style: [ styles[:cell], styles[:cell], styles[:cell], styles[:cell], styles[:name] ]
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
      sheet.column_widths(16, 10, 8, 14, 60)

      detail_row_count = @rows.sum { |row| row.new_students.size + row.expand_students.size + row.return_students.size }
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
        pane.top_left_cell = "A#{DATA_START_ROW}"
        pane.y_split = HEADER_ROW
        pane.active_pane = :bottom_left
      end
      sheet.column_widths(16, 10, 8, 8, 10, 8, 10, 8, 10)

      return if @data_row_count.zero?

      data_end_row = DATA_START_ROW + @data_row_count - 1
      sheet.auto_filter = "A#{HEADER_ROW}:#{last_column}#{data_end_row}"
    end

    def last_column
      Axlsx.col_ref(HEADERS.size - 1)
    end
end
