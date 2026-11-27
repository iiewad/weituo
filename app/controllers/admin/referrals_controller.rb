class Admin::ReferralsController < AdminController
  PER_PAGE_OPTIONS = [ 20, 30, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 20
  PERIODS = {
    "month" => "本月",
    "quarter" => "近3个月",
    "year" => "近12个月"
  }.freeze

  def index
    load_referral_data

    @per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : DEFAULT_PER_PAGE
    @per_page_options = PER_PAGE_OPTIONS

    @referral_records = apply_name_filter(@referrals).order(created_at: :desc)
      .page(params[:page]).per(@per_page)
      .includes(referrer: :grade, referred: :grade)
  end

  def export
    load_referral_data

    send_data ReferralSheet.new(
      campuse: Current.campuse,
      filter_summary: referral_filter_summary,
      referral_count: @referral_count,
      referrer_count: @referrer_count,
      this_month_count: @this_month_count,
      average_per_referrer: @average_per_referrer,
      top_referrers: @top_referrers,
      counts_by_referrer: @counts_by_referrer,
      grade_distribution: @grade_distribution,
      records: apply_name_filter(@referrals).order(created_at: :desc).includes(referrer: :grade, referred: :grade),
      name_query: @name
    ).to_xlsx,
    filename: "推荐看板-#{Current.campuse.name}.xlsx",
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    disposition: "attachment"
  end

  private
    def load_referral_data
      @name = params[:name].to_s.strip.presence
      @grades = Current.user.grades_by_campuse(Current.campuse.id).order(:level)
      student_ids = Student.active.where(campuse_id: Current.campuse.id, grade_id: @grades.ids).select(:id)
      @referrals = StudentReferral.where(referrer_id: student_ids, referred_id: student_ids)

      @selected_grade = @grades.find_by(id: params[:grade_id])
      if @selected_grade
        referrer_ids = Student.active.where(grade_id: @selected_grade.id).select(:id)
        @referrals = @referrals.where(referrer_id: referrer_ids)
      end

      @period = PERIODS.key?(params[:period]) ? params[:period] : nil
      @referrals = @referrals.where(created_at: period_start(@period)..) if @period

      @referral_count = @referrals.count
      @referrer_count = @referrals.distinct.count(:referrer_id)
      @this_month_count = @referrals.where(created_at: Time.current.beginning_of_month..).count
      @average_per_referrer = @referrer_count.zero? ? 0 : (@referral_count.to_f / @referrer_count).round(1)

      @counts_by_referrer = @referrals.group(:referrer_id).count
      @top_referrers = Student.where(id: @counts_by_referrer.keys)
        .includes(:grade)
        .sort_by { |student| [ -@counts_by_referrer[student.id], student.name ] }
        .first(10)
      @max_referral_count = [ @counts_by_referrer.values.max.to_i, 1 ].max

      referred_counts = Student.where(id: @referrals.select(:referred_id)).group(:grade_id).count
      @grade_distribution = @grades.filter_map do |grade|
        count = referred_counts[grade.id].to_i
        [ grade, count ] if count.positive?
      end
      @max_grade_count = [ @grade_distribution.map(&:last).max.to_i, 1 ].max
    end

    # 人名搜索只作用于推荐明细：推荐人或被推荐学员任一方姓名命中即保留
    def apply_name_filter(scope)
      return scope if @name.blank?

      matched_ids = Student.active.where(campuse_id: Current.campuse.id)
        .where("name LIKE ?", "%#{Student.sanitize_sql_like(@name)}%")
        .select(:id)
      scope.where(referrer_id: matched_ids).or(scope.where(referred_id: matched_ids))
    end

    def period_start(period)
      case period
      when "month"   then Time.current.beginning_of_month
      when "quarter" then 3.months.ago.beginning_of_month
      when "year"    then 12.months.ago.beginning_of_month
      end
    end

    def referral_filter_summary
      parts = []
      parts << "推荐人年级：#{@selected_grade.name}" if @selected_grade
      parts << "时间范围：#{PERIODS[@period]}" if @period
      parts.empty? ? "全部推荐" : parts.join(" · ")
    end
end
