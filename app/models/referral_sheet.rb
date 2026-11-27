class ReferralSheet
  SUMMARY_COLUMNS = 8
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
        title: styles.add_style(sz: 14, b: true, alignment: { vertical: :center }, **XlsxStyle::BORDER),
        section: styles.add_style(b: true, sz: 12, fg_color: "334155", **XlsxStyle::BORDER),
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

    # 汇总表各小节行数动态，合并与铺宽统一按当前实际行号处理
    def build_summary(sheet, styles)
      XlsxStyle.merged_row(sheet, "#{@campuse.name} · 推荐看板", styles[:title], SUMMARY_COLUMNS)

      XlsxStyle.full_row(
        sheet,
        [ "推荐总数", "#{@referral_count} 条", "推荐人", "#{@referrer_count} 人",
          "本月新增", "#{@this_month_count} 条", "人均推荐", "#{@average_per_referrer} 条/人" ],
        [ styles[:label], styles[:value] ] * 4,
        SUMMARY_COLUMNS
      )

      XlsxStyle.merged_row(sheet, "筛选条件：#{@filter_summary}", styles[:value], SUMMARY_COLUMNS)

      XlsxStyle.merged_row(sheet, "推荐排行（前10）", styles[:section], SUMMARY_COLUMNS)

      sheet.add_row(RANKING_HEADERS, style: styles[:header])
      if @top_referrers.empty?
        XlsxStyle.merged_row(sheet, "当前筛选条件下没有推荐记录", styles[:cell], SUMMARY_COLUMNS)
      else
        @top_referrers.each.with_index(1) do |student, index|
          XlsxStyle.full_row(
            sheet,
            [ index, student.identity_label, student.grade&.name || "—", @counts_by_referrer[student.id].to_i ],
            [ styles[:cell], styles[:name], styles[:cell], styles[:cell] ],
            SUMMARY_COLUMNS
          )
        end
      end

      XlsxStyle.merged_row(sheet, "被推荐学员年级分布", styles[:section], SUMMARY_COLUMNS)

      sheet.add_row(DISTRIBUTION_HEADERS, style: styles[:header])
      if @grade_distribution.empty?
        XlsxStyle.merged_row(sheet, "当前筛选条件下没有推荐记录", styles[:cell], SUMMARY_COLUMNS)
      else
        @grade_distribution.each do |grade, count|
          XlsxStyle.full_row(sheet, [ grade.name, count ], [ styles[:name], styles[:cell] ], SUMMARY_COLUMNS)
        end
      end

      sheet.sheet_view.show_grid_lines = false
      sheet.column_widths(10, 20, 12, 12, 12, 12, 12, 14)
    end

    def build_detail_header(sheet, styles)
      XlsxStyle.merged_row(sheet, "推荐明细", styles[:title], DETAIL_HEADERS.size)

      XlsxStyle.merged_row(sheet, "筛选条件：#{detail_filter_summary}", styles[:value], DETAIL_HEADERS.size)

      sheet.add_row(DETAIL_HEADERS, style: styles[:header])
    end

    def build_detail_rows(sheet, styles)
      if @records.empty?
        XlsxStyle.merged_row(sheet, "当前筛选条件下没有推荐记录", styles[:cell], DETAIL_HEADERS.size)
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
end
