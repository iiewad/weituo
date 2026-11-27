class ReferralSheet
  DETAIL_TITLE_ROW = 1
  DETAIL_FILTER_ROW = 2
  DETAIL_HEADER_ROW = 3
  DETAIL_DATA_START_ROW = 4
  DETAIL_HEADERS = %w[被推荐学员 年级 推荐人 推荐人年级 推荐时间]

  RANKING_HEADERS = %w[排名 推荐人 年级 推荐人数]
  DISTRIBUTION_HEADERS = %w[年级 人数]

  def initialize(campuse:, filter_summary:, referral_count:, referrer_count:, this_month_count:,
    average_per_referrer:, top_referrers:, counts_by_referrer:, grade_distribution:, records:, name_query: nil)
    @campuse = campuse
    @filter_summary = filter_summary
    @referral_count = referral_count
    @referrer_count = referrer_count
    @this_month_count = this_month_count
    @average_per_referrer = average_per_referrer
    @top_referrers = top_referrers
    @counts_by_referrer = counts_by_referrer
    @grade_distribution = grade_distribution
    @records = records
    @name_query = name_query
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true
    workbook = package.workbook
    styles = build_styles(workbook)

    workbook.add_worksheet(name: "推荐汇总") do |sheet|
      build_summary(sheet, styles)
    end

    workbook.add_worksheet(name: "推荐明细") do |sheet|
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
        title: styles.add_style(sz: 14, b: true, alignment: { vertical: :center }),
        section: styles.add_style(b: true, sz: 12, fg_color: "334155"),
        label: styles.add_style(b: true, fg_color: "475569"),
        value: styles.add_style({}),
        header: styles.add_style(
          b: true,
          bg_color: "F1F5F9",
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          border: { style: :thin, color: "CBD5E1" }
        ),
        name: styles.add_style(alignment: { horizontal: :left }),
        cell: styles.add_style(alignment: { horizontal: :center })
      }
    end

    # 汇总表各小节行数动态，逐行记录当前行号用于合并单元格
    def build_summary(sheet, styles)
      row = 0

      row += 1
      sheet.add_row([ "#{@campuse.name} · 推荐看板" ], style: styles[:title])
      sheet.merge_cells("A#{row}:#{summary_last_column}#{row}")

      row += 1
      sheet.add_row(
        [ "推荐总数", "#{@referral_count} 条", "推荐人", "#{@referrer_count} 人",
          "本月新增", "#{@this_month_count} 条", "人均推荐", "#{@average_per_referrer} 条/人" ],
        style: [ styles[:label], styles[:value] ] * 4
      )

      row += 1
      sheet.add_row([ "筛选条件：#{@filter_summary}" ], style: styles[:value])
      sheet.merge_cells("A#{row}:#{summary_last_column}#{row}")

      row += 2
      sheet.add_row([ "推荐排行（前10）" ], style: styles[:section])
      sheet.merge_cells("A#{row}:#{summary_last_column}#{row}")

      row += 1
      sheet.add_row(RANKING_HEADERS, style: styles[:header])
      if @top_referrers.empty?
        row += 1
        sheet.add_row([ "当前筛选条件下没有推荐记录" ], style: styles[:cell])
        sheet.merge_cells("A#{row}:#{summary_last_column}#{row}")
      else
        @top_referrers.each.with_index(1) do |student, index|
          row += 1
          sheet.add_row(
            [ index, student.identity_label, student.grade&.name || "—", @counts_by_referrer[student.id].to_i ],
            style: [ styles[:cell], styles[:name], styles[:cell], styles[:cell] ]
          )
        end
      end

      row += 2
      sheet.add_row([ "被推荐学员年级分布" ], style: styles[:section])
      sheet.merge_cells("A#{row}:#{summary_last_column}#{row}")

      row += 1
      sheet.add_row(DISTRIBUTION_HEADERS, style: styles[:header])
      if @grade_distribution.empty?
        row += 1
        sheet.add_row([ "当前筛选条件下没有推荐记录" ], style: styles[:cell])
        sheet.merge_cells("A#{row}:#{summary_last_column}#{row}")
      else
        @grade_distribution.each do |grade, count|
          row += 1
          sheet.add_row([ grade.name, count ], style: [ styles[:name], styles[:cell] ])
        end
      end

      sheet.sheet_view.show_grid_lines = false
      sheet.column_widths(10, 20, 12, 12, 12, 12, 12, 14)
    end

    def build_detail_header(sheet, styles)
      sheet.add_row([ "推荐明细" ], style: styles[:title])
      sheet.merge_cells("A#{DETAIL_TITLE_ROW}:#{detail_last_column}#{DETAIL_TITLE_ROW}")

      sheet.add_row([ "筛选条件：#{detail_filter_summary}" ], style: styles[:value])
      sheet.merge_cells("A#{DETAIL_FILTER_ROW}:#{detail_last_column}#{DETAIL_FILTER_ROW}")

      sheet.add_row(DETAIL_HEADERS, style: styles[:header])
    end

    def build_detail_rows(sheet, styles)
      if @records.empty?
        sheet.add_row([ "当前筛选条件下没有推荐记录" ], style: styles[:cell])
        sheet.merge_cells("A#{DETAIL_DATA_START_ROW}:#{detail_last_column}#{DETAIL_DATA_START_ROW}")
        return
      end

      @records.each do |referral|
        sheet.add_row(
          [
            referral.referred.identity_label,
            referral.referred.grade&.name || "—",
            referral.referrer.identity_label,
            referral.referrer.grade&.name || "—",
            referral.created_at.strftime("%Y-%m-%d %H:%M")
          ],
          style: [ styles[:name], styles[:cell], styles[:name], styles[:cell], styles[:cell] ]
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
      sheet.column_widths(20, 12, 20, 12, 18)

      record_count = @records.size
      return if record_count.zero?

      data_end_row = DETAIL_DATA_START_ROW + record_count - 1
      sheet.auto_filter = "A#{DETAIL_HEADER_ROW}:#{detail_last_column}#{data_end_row}"
    end

    def detail_last_column
      Axlsx.col_ref(DETAIL_HEADERS.size - 1)
    end

    # 明细页含人名搜索口径；汇总页仍用 @filter_summary（年级+时间），与其数据一致
    def detail_filter_summary
      return @filter_summary if @name_query.blank?

      "#{@filter_summary} · 姓名搜索：#{@name_query}"
    end

    def summary_last_column
      "H"
    end
end
