class DaySchool < ApplicationRecord
  belongs_to :campuse
  has_many :students

  validates :name, presence: true,
    uniqueness: { scope: :campuse_id, message: "在当前校区已存在" }

  IMPORT_HEADERS = [ "日校", "日校名称", "名称", "name" ].freeze

  # 按行导入日校名称（取每行第一列，兼容从 Excel 粘贴的多列表格），返回 [新增数, 跳过数]
  def self.add_by_text(campuse_id, str)
    created = 0
    skipped = 0

    str.to_s.split("\n").each do |line|
      name = line.strip.split(/[,\t，]/).first.to_s.strip
      next if name.blank? || IMPORT_HEADERS.include?(name)

      day_school = new(name: name, campuse_id: campuse_id)
      if day_school.save
        created += 1
      else
        skipped += 1
      end
    end

    [ created, skipped ]
  end
end
