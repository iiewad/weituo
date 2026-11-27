class Student < ApplicationRecord
  paginates_per 30
  validates :name, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  belongs_to :day_school, optional: true
  belongs_to :campuse
  belongs_to :grade, optional: true
  has_many :guardians, dependent: :destroy
  has_many :klass_students, -> { active }
  has_many :all_klass_students, class_name: "KlassStudent", dependent: :destroy
  has_one :received_referral, class_name: "StudentReferral", foreign_key: :referred_id, dependent: :destroy, inverse_of: :referred
  has_one :referrer, through: :received_referral
  has_many :given_referrals, class_name: "StudentReferral", foreign_key: :referrer_id, dependent: :destroy, inverse_of: :referrer
  has_many :referred_students, through: :given_referrals, source: :referred
  accepts_nested_attributes_for :guardians, reject_if: :all_blank, allow_destroy: true

  attr_writer :referrer_id
  after_save :sync_referrer, unless: -> { @referrer_id.nil? }
  before_save :assign_name_seq, if: :name_seq_needs_assignment?

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "grade_id" ]
  end

  # 同名学员的辅助区分信息：同校区同名按建档顺序累加序号，仅重名时展示。
  def identity_suffix
    "序号 #{name_seq}" if name_seq.to_i > 1
  end

  def identity_detail
    [ grade&.name, identity_suffix ].compact.join(" · ")
  end

  def identity_label
    suffix = identity_suffix
    suffix.present? ? "#{name}（#{suffix}）" : name
  end

  # mark_previous_absent: 入班课次之前的课次是否补记缺课；转出到目标班时传 false
  # reinstate: 已有报名处于退课/转出时是否恢复在班；从转入班反向转回原班时传 true
  # transfer_from: 转入来源班；非空时记录来源班与入班课次，供转入班展示转入信息
  def join_klass(sk, course_seq: 1, mark_previous_absent: true, reinstate: false, transfer_from: nil)
    # 学员年级与班级年级一致才可进班；预留分班须先把学员升级到目标年级
    return if sk.grade_id != grade_id
    return if sk.campuse_id != campuse_id

    course = sk.courses.find_by(seq: course_seq)
    return if course.blank?

    ks = KlassStudent.unscoped.find_or_initialize_by(semester_klass_id: sk.id, student_id: id)
    if ks.new_record?
      ks.save!
    elsif ks.archived_at.present?
      ks.restore!
    elsif reinstate && ks.status.in?([ "out", "transfer" ])
      ks.update!(status: :in)
    end
    ks.update!(transfer_source_klass_id: transfer_from.id, transfer_in_seq: course_seq) if transfer_from

    if mark_previous_absent
      sk.courses.where("seq < ?", course_seq).each do |course|
        attendance = course.attendances.find_or_create_by(klass_student_id: ks.id)
        attendance.update!(status: "absent")
      end
    end
    sk.courses.where("seq >= ? AND start_date IS NOT NULL", course_seq).each do |course|
      attendance = course.attendances.find_or_create_by(klass_student_id: ks.id)
    end
  end

  # 转入时把目标班入班课次（before_seq）之前、已开课的课次标记为「转入」，表示这些课次学员尚未
  # 转入本班、未在本班就读；源班的真实考勤保留在源班，不再复制到目标班。
  # 已有真实考勤的行保留（反向转回原班时原班出勤不被覆盖），只把缺口 / 退课 / 转出行改为转入。
  def mark_transferred_in_attendances(to_klass, before_seq:)
    to_ks = to_klass.klass_students.find_by(student_id: id)
    return if to_ks.blank?

    to_klass.courses.where("seq < ?", before_seq).find_each do |course|
      next unless course.started?

      row = course.attendances.find_or_initialize_by(klass_student_id: to_ks.id)
      next if row.persisted? && !row.status.in?(%w[quit transfer])

      row.update!(status: "transfer_in")
    end
  end

  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def update_grade
    target_grade = Grade.find_by(level: grade.level.to_i + 1)
    update!(grade_id: target_grade.id) if target_grade.present?
  end

  # 表单里通过 student[referrer_id] 提交推荐人；留空表示清除推荐关系。
  def referrer_id
    return @referrer_id if defined?(@referrer_id)

    received_referral&.referrer_id
  end

  IMPORT_HEADERS = [ "姓名", "name", "学生姓名", "学员姓名" ].freeze

  # 按 CSV 行导入学员：前 8 列为学员信息（姓名,性别,生日,年级level,层级,入学日期,日校,家庭住址），
  # 之后每 4 列一位监护人（姓名,电话,关系,职业），可写多名；返回 [新增人数, 跳过行数]。
  IMPORT_STUDENT_COLUMNS = 8
  IMPORT_GUARDIAN_COLUMNS = 4
  def self.add_by_text(campuse_id, str, grade_ids: nil)
    rows = str.to_s.split("\n").map { |line| normalize_import_row(line.split(",", -1)) }
    import_rows(campuse_id, rows, grade_ids:)
  end

  # 读取 xlsx 首张工作表导入，列顺序与 CSV 一致，首行表头可有可无。
  def self.add_by_xlsx(campuse_id, file, grade_ids: nil)
    spreadsheet = Roo::Spreadsheet.open(file.path, extension: :xlsx)
    rows = spreadsheet.sheet(0).to_a.map { |row| normalize_import_row(row) }
    import_rows(campuse_id, rows, grade_ids:)
  end

  def self.import_rows(campuse_id, rows, grade_ids: nil)
    campuse = Campuse.find(campuse_id)
    created = 0
    skipped = 0

    transaction do
      rows.each do |row|
        next if row.all? { |value| value.to_s.strip.blank? }
        next if IMPORT_HEADERS.include?(row.first.to_s.strip)

        name, gender, birthday, grade_level, layer, in_date, day_school_name, address =
          row.first(IMPORT_STUDENT_COLUMNS).map { |value| value.to_s.strip }
        guardian_rows = row.drop(IMPORT_STUDENT_COLUMNS).each_slice(IMPORT_GUARDIAN_COLUMNS).map do |group|
          group.map { |value| value.to_s.strip }
        end
        grade = Grade.find_by(level: grade_level)
        day_school = campuse.day_schools.find_by(name: day_school_name)

        if name.blank? || grade.blank? || day_school.blank? || (grade_ids && !grade_ids.include?(grade.id))
          skipped += 1
          next
        end

        gender = {
          "男" => "male", "女" => "female",
          "male" => "male", "female" => "female"
        }[gender]

        student = import_student(campuse_id, {
          name: name,
          gender: gender,
          birthday: birthday,
          grade_id: grade.id,
          layer: layer,
          in_date: in_date,
          day_school_id: day_school.id,
          address: address.presence
        })

        if student.new_record? && !student.save
          skipped += 1
          next
        end

        # 每位监护人 4 列，姓名选填、电话必填；有电话就建档，可导入多名监护人
        guardian_rows.each do |guardian_name, guardian_phone, guardian_relationship, guardian_occupation|
          next if guardian_phone.blank?

          student.guardians.find_or_create_by(name: guardian_name.presence, phone: guardian_phone) do |guardian|
            guardian.relationship = guardian_relationship.presence
            guardian.occupation = guardian_occupation.presence
          end
        end

        student.previously_new_record? ? created += 1 : skipped += 1
      end
    end

    [ created, skipped ]
  end

  # 导入去重键：校区 + 姓名 + 生日；生日缺失时退回 校区 + 姓名 + 年级。
  # 年级、日校、入学日期等会变化的属性不参与比对，避免同一学员重复建档。
  def self.import_student(campuse_id, attributes)
    scope = where(campuse_id: campuse_id, name: attributes[:name])
    scope = if attributes[:birthday].present?
      scope.where(birthday: attributes[:birthday])
    else
      scope.where(birthday: nil, grade_id: attributes[:grade_id])
    end

    scope.order(:id).first || new(attributes.merge(campuse_id: campuse_id))
  end
  private_class_method :import_student

  # xlsx 里生日/入学日期可能是 Date 或未格式化的 Excel 序列号。
  def self.normalize_import_row(row)
    row.each_with_index.map do |value, index|
      index.in?([ 2, 5 ]) ? normalize_import_date(value) : normalize_import_value(value)
    end
  end

  def self.normalize_import_date(value)
    case value
    when Date then value.strftime("%Y-%m-%d")
    when Time then value.to_date.strftime("%Y-%m-%d")
    when Numeric then (Date.new(1899, 12, 30) + value.to_i).strftime("%Y-%m-%d")
    else value.to_s.strip
    end
  end

  def self.normalize_import_value(value)
    case value
    when Float then value == value.to_i ? value.to_i.to_s : value.to_s
    else value.to_s.strip
    end
  end

  private
    def name_seq_needs_assignment?
      new_record? || will_save_change_to_name? || will_save_change_to_campuse_id?
    end

    # 同名序号在同一校区内唯一。锁住校区行再比对，避免并发建档拿到相同序号。
    # 改名 / 转校区时只要原序号没被占用就保留，保证「序号 N」这个身份标识稳定。
    def assign_name_seq
      campuse.with_lock do
        siblings = self.class.where(campuse_id: campuse_id, name: name).where.not(id: id).lock.to_a

        next if name_seq.present? && siblings.none? { |sibling| sibling.name_seq == name_seq }

        self.name_seq = siblings.map(&:name_seq).max.to_i + 1
      end
    end

    def sync_referrer
      if @referrer_id.blank?
        received_referral&.destroy
        return
      end

      referrer = self.class.find_by(id: @referrer_id, campuse_id: campuse_id)
      return if referrer.nil? || referrer.id == id

      StudentReferral.find_or_initialize_by(referred_id: id).update!(referrer_id: referrer.id)
    end
end
