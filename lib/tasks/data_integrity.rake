namespace :data do
  desc "检查唯一约束和外键迁移前的重复/孤儿数据"
  task integrity: :environment do
    connection = ActiveRecord::Base.connection
    failures = []

    duplicate_checks = {
      "学员同名序号" => [ "students", %w[campuse_id name name_seq] ],
      "推荐关系" => [ "student_referrals", %w[referred_id] ],
      "班级业务键" => [ "semester_klasses", %w[semester_id campuse_id grade_id subject_id genre seq] ],
      "课次序号" => [ "courses", %w[semester_klass_id seq] ],
      "班级报名" => [ "klass_students", %w[semester_klass_id student_id] ],
      "课程考勤" => [ "attendances", %w[course_id klass_student_id] ],
      "用户校区授权" => [ "user_campuses", %w[user_id campuse_id] ],
      "学校年级科目" => [ "grade_subjects", %w[school_id semester_id grade_id subject_id] ],
      "学校学期序号" => [ "semesters", %w[school_id seq] ]
    }

    orphan_checks = {
      "校区 → 学校" => "campuses c LEFT JOIN schools s ON s.id = c.school_id WHERE s.id IS NULL",
      "学期 → 学校" => "semesters s LEFT JOIN schools sc ON sc.id = s.school_id WHERE sc.id IS NULL",
      "日校 → 校区" => "day_schools d LEFT JOIN campuses c ON c.id = d.campuse_id WHERE c.id IS NULL",
      "年级科目 → 学校/学期/年级/科目" => "grade_subjects gs LEFT JOIN schools s ON s.id = gs.school_id LEFT JOIN semesters se ON se.id = gs.semester_id LEFT JOIN grades g ON g.id = gs.grade_id LEFT JOIN subjects sub ON sub.id = gs.subject_id WHERE s.id IS NULL OR se.id IS NULL OR g.id IS NULL OR sub.id IS NULL",
      "学员 → 校区/年级/日校" => "students st LEFT JOIN campuses c ON c.id = st.campuse_id LEFT JOIN grades g ON g.id = st.grade_id LEFT JOIN day_schools d ON d.id = st.day_school_id WHERE c.id IS NULL OR (st.grade_id IS NOT NULL AND g.id IS NULL) OR (st.day_school_id IS NOT NULL AND d.id IS NULL)",
      "监护人 → 学员" => "guardians gu LEFT JOIN students st ON st.id = gu.student_id WHERE st.id IS NULL",
      "教师 → 校区/科目" => "teachers t LEFT JOIN campuses c ON c.id = t.campuse_id LEFT JOIN subjects sub ON sub.id = t.subject_id WHERE c.id IS NULL OR sub.id IS NULL",
      "班级 → 校区/学期/年级/科目/教师" => "semester_klasses sk LEFT JOIN campuses c ON c.id = sk.campuse_id LEFT JOIN semesters se ON se.id = sk.semester_id LEFT JOIN grades g ON g.id = sk.grade_id LEFT JOIN subjects sub ON sub.id = sk.subject_id LEFT JOIN teachers t ON t.id = sk.teacher_id WHERE (sk.campuse_id IS NOT NULL AND c.id IS NULL) OR se.id IS NULL OR g.id IS NULL OR (sk.subject_id IS NOT NULL AND sub.id IS NULL) OR (sk.teacher_id IS NOT NULL AND t.id IS NULL)",
      "课次 → 班级" => "courses co LEFT JOIN semester_klasses sk ON sk.id = co.semester_klass_id WHERE sk.id IS NULL",
      "报名 → 班级/学员" => "klass_students ks LEFT JOIN semester_klasses sk ON sk.id = ks.semester_klass_id LEFT JOIN students st ON st.id = ks.student_id WHERE sk.id IS NULL OR st.id IS NULL",
      "考勤 → 课次/报名" => "attendances a LEFT JOIN courses co ON co.id = a.course_id LEFT JOIN klass_students ks ON ks.id = a.klass_student_id WHERE co.id IS NULL OR (a.klass_student_id IS NOT NULL AND ks.id IS NULL)",
      "用户校区授权 → 用户/校区/学校" => "user_campuses uc LEFT JOIN users u ON u.id = uc.user_id LEFT JOIN campuses c ON c.id = uc.campuse_id LEFT JOIN schools s ON s.id = uc.school_id WHERE u.id IS NULL OR c.id IS NULL OR s.id IS NULL",
      "推荐关系 → 推荐人/被推荐人" => "student_referrals sr LEFT JOIN students r ON r.id = sr.referrer_id LEFT JOIN students d ON d.id = sr.referred_id WHERE r.id IS NULL OR d.id IS NULL",
      "会话 → 用户" => "sessions se LEFT JOIN users u ON u.id = se.user_id WHERE u.id IS NULL"
    }

    puts "数据完整性检查"

    duplicate_checks.each do |label, (table, columns)|
      rows = connection.select_all(
        "SELECT #{columns.join(', ')}, COUNT(*) AS duplicate_count FROM #{table} " \
        "GROUP BY #{columns.join(', ')} HAVING COUNT(*) > 1 LIMIT 20"
      ).to_a
      next if rows.empty?

      failures << label
      puts "  ✗ 重复：#{label}（#{rows.size} 组，最多显示 20 组）"
    end

    orphan_checks.each do |label, sql|
      count = connection.select_value("SELECT COUNT(*) FROM (SELECT 1 FROM #{sql}) AS broken_rows").to_i
      next if count.zero?

      failures << label
      puts "  ✗ 孤儿：#{label}（#{count} 条）"
    end

    if failures.any?
      puts "检查失败：#{failures.uniq.join('、')}"
      exit 1
    end

    puts "检查通过：未发现重复或孤儿数据"
  end
end
