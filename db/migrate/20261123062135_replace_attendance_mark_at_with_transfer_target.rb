class ReplaceAttendanceMarkAtWithTransferTarget < ActiveRecord::Migration[8.1]
  def up
    add_column :attendances, :transfer_target_klass_id, :bigint

    # 把原来埋在 mark_at JSON 里的转出目标班迁移成外键列
    execute <<~SQL
      UPDATE attendances
      SET transfer_target_klass_id = CAST(
        JSON_UNQUOTE(JSON_EXTRACT(mark_at, '$.transfer_target_klass_id')) AS UNSIGNED
      )
      WHERE mark_at IS NOT NULL
        AND JSON_EXTRACT(mark_at, '$.transfer_target_klass_id') IS NOT NULL
    SQL

    # 目标班可能已被删除，清掉悬空引用后再加外键
    execute <<~SQL
      UPDATE attendances
      SET transfer_target_klass_id = NULL
      WHERE transfer_target_klass_id IS NOT NULL
        AND transfer_target_klass_id NOT IN (SELECT id FROM semester_klasses)
    SQL

    add_index :attendances, :transfer_target_klass_id
    add_foreign_key :attendances, :semester_klasses, column: :transfer_target_klass_id, on_delete: :nullify

    # 各状态时间戳只被内部写入，变更时间统一看 updated_at
    remove_column :attendances, :mark_at
  end

  def down
    add_column :attendances, :mark_at, :json
    execute <<~SQL
      UPDATE attendances
      SET mark_at = JSON_OBJECT('transfer_target_klass_id', transfer_target_klass_id)
      WHERE transfer_target_klass_id IS NOT NULL
    SQL

    remove_foreign_key :attendances, column: :transfer_target_klass_id
    remove_column :attendances, :transfer_target_klass_id
  end
end
