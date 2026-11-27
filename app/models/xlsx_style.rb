# 报表导出共用样式：细框线；合并行需铺满整行再加框线，否则合并区内无边框
module XlsxStyle
  BORDER = { border: { style: :thin, color: "CBD5E1" } }.freeze

  def self.full_row(sheet, values, style, columns)
    values = values.dup
    values << nil while values.size < columns
    if style.is_a?(Array)
      style = style.dup
      style << style.last while style.size < values.size
    end
    sheet.add_row(values, style: style)
  end

  def self.merged_row(sheet, text, style, columns)
    full_row(sheet, [ text ], style, columns)
    sheet.merge_cells("A#{sheet.rows.size}:#{Axlsx.col_ref(columns - 1)}#{sheet.rows.size}")
  end
end
