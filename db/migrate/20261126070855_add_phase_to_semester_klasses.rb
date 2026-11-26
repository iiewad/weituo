class AddPhaseToSemesterKlasses < ActiveRecord::Migration[8.1]
  def change
    add_column :semester_klasses, :phase, :integer, null: false, default: 1

    # 同一学期的第一阶段 / 第二阶段可以重复使用班型 + 序号，业务唯一键要带上阶段。
    # 旧索引同时支撑 semester_id 外键，必须先建新索引再删旧索引。
    add_index :semester_klasses,
      [ :semester_id, :campuse_id, :grade_id, :subject_id, :genre, :seq, :phase ],
      unique: true, name: "index_semester_klasses_on_business_key_v2"
    remove_index :semester_klasses, name: "index_semester_klasses_on_business_key"
    rename_index :semester_klasses,
      "index_semester_klasses_on_business_key_v2", "index_semester_klasses_on_business_key"
  end
end
