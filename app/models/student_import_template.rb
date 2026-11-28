class StudentImportTemplate
  HEADERS = [
    "姓名", "性别", "生日", "年级", "层级", "入学学期", "日校", "家庭住址",
    "监护人1姓名", "监护人1电话", "监护人1关系", "监护人1职业",
    "监护人2姓名", "监护人2电话", "监护人2关系", "监护人2职业"
  ].freeze
  EXAMPLES = [
    [ "张三", "男", "2013-05-01", "7", "3", "2026秋季", "一中", "和平路 88 号",
      "张建国", "13800000000", "父亲", "工程师", "李梅", "13900000000", "母亲", "医生" ],
    [ "李四", "女", "2012-11-20", "8", "2", "2026秋季", "二中",
      "", "", "", "", "", "", "", "" ]
  ].freeze

  def to_xlsx
    package = Axlsx::Package.new
    package.use_shared_strings = true
    workbook = package.workbook
    styles = build_styles(workbook)

    add_import_sheet(workbook, styles)
    add_guide_sheet(workbook, styles)

    package.to_stream.read
  end

  private
    def build_styles(workbook)
      styles = workbook.styles
      {
        header: styles.add_style(
          b: true,
          bg_color: "F1F5F9",
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          border: { style: :thin, color: "CBD5E1" }
        ),
        title: styles.add_style(sz: 13, b: true),
        text: styles.add_style(alignment: { vertical: :top }),
        muted: styles.add_style(fg_color: "64748B", sz: 10)
      }
    end

    def add_import_sheet(workbook, styles)
      workbook.add_worksheet(name: "学员导入") do |sheet|
        sheet.add_row(HEADERS, style: styles[:header])
        sheet.sheet_view.pane do |pane|
          pane.state = :frozen
          pane.top_left_cell = "A2"
          pane.y_split = 1
          pane.active_pane = :bottom_left
        end
        sheet.column_widths(14, 8, 14, 8, 8, 14, 14, 22, 14, 16, 10, 10, 14, 16, 10, 10)
      end
    end

    def add_guide_sheet(workbook, styles)
      workbook.add_worksheet(name: "填写说明") do |sheet|
        sheet.add_row([ "学员批量导入填写说明" ], style: styles[:title])
        sheet.merge_cells("A1:F1")

        [
          "1. 在「学员导入」工作表第 2 行开始填写，首行表头请勿删除或改名。",
          "2. 年级填 level（如 7、8、9）；日校必须是当前校区已有的名称。",
          "3. 入学学期填所在学校已有的学期名称，可留空；匹配不到时入学学期留空，不影响建档。",
          "4. 性别填 男 / 女，也支持 male / female。",
          "5. 家庭住址选填，会写入学员档案。",
          "6. 监护人从第 9 列开始，每人 4 列（姓名、电话、关系、职业），可填写多名；填写电话即创建，其余可留空。",
          "7. 同一校区内姓名和生日相同的学员会跳过；年级或日校不匹配、或不在授权范围内的行会跳过。",
          "8. 导入只创建学员档案（及可选监护人），不会自动加入班级。"
        ].each { |line| sheet.add_row([ line ], style: styles[:text]) }

        sheet.add_row([])
        sheet.add_row([ "示例数据" ], style: styles[:title])
        sheet.add_row(HEADERS, style: styles[:header])
        EXAMPLES.each { |row| sheet.add_row(row, style: styles[:text]) }

        sheet.column_widths(18, 10, 14, 10, 10, 14, 14, 22, 14, 16, 10, 10, 14, 16, 10, 10)
      end
    end
end
