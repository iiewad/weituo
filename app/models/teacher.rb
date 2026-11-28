class Teacher < ApplicationRecord
  belongs_to :subject
  belongs_to :campuse

  validates :name, presence: true
  validate :subject_offered_by_campuse

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "phone", "subject_id", "campuse_id" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "subject", "campuse" ]
  end

  IMPORT_HEADERS = [ "科目", "subject" ].freeze

  # 按行导入教师：科目,姓名,电话（支持英文/中文逗号与制表符），返回 [新增数, 跳过数]
  def self.add_by_text(campuse_id, str)
    created = 0
    skipped = 0

    str.to_s.split("\n").each do |line|
      next if line.strip.blank?

      parts = line.strip.split(/[,\t，]/).map(&:strip)
      next if IMPORT_HEADERS.include?(parts.first)

      subject_name, name, phone = parts
      subject = Subject.find_by(name: subject_name, campuse_id: campuse_id)
      if subject.blank? || name.blank?
        skipped += 1
        next
      end

      teacher = find_or_initialize_by(name: name, subject_id: subject.id, campuse_id: campuse_id)
      if teacher.persisted?
        skipped += 1
        next
      end

      teacher.phone = phone.presence
      if teacher.save
        created += 1
      else
        skipped += 1
      end
    end

    [ created, skipped ]
  end

  def name_with_subject
    "#{subject.name} #{name}"
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  private
    def subject_offered_by_campuse
      return if subject.blank? || campuse.blank?
      return if campuse.subjects.exists?(id: subject_id)

      errors.add(:subject_id, "未在该校区开设")
    end
end
