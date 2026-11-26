class AddCurrentToSemestersRemoveDates < ActiveRecord::Migration[8.1]
  def up
    add_column :semesters, :current, :boolean, default: false, null: false

    # 迁移前按原日期规则确定当前学期，日期移除后就靠这个标记
    execute "UPDATE semesters SET current = 1 WHERE start_date <= CURDATE() AND end_date >= CURDATE()"

    # 没有学期覆盖今天的学校，用序号最大的学期兜底
    select_rows("SELECT school_id, MAX(seq) FROM semesters GROUP BY school_id").each do |school_id, max_seq|
      next if select_value("SELECT 1 FROM semesters WHERE school_id = #{school_id.to_i} AND current = 1 LIMIT 1")

      execute("UPDATE semesters SET current = 1 WHERE school_id = #{school_id.to_i} AND seq = #{max_seq.to_i}")
    end

    remove_column :semesters, :start_date
    remove_column :semesters, :end_date
  end

  def down
    add_column :semesters, :start_date, :date
    add_column :semesters, :end_date, :date
    remove_column :semesters, :current
  end
end
