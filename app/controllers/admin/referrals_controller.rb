class Admin::ReferralsController < AdminController
  PER_PAGE = 20

  def index
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).order(:level)
    student_ids = Student.where(campuse_id: Thread.current[:campuse].id, grade_id: @grades.ids).select(:id)
    @referrals = StudentReferral.where(referrer_id: student_ids, referred_id: student_ids)

    @selected_grade = @grades.find_by(id: params[:grade_id])
    if @selected_grade
      referrer_ids = Student.where(grade_id: @selected_grade.id).select(:id)
      @referrals = @referrals.where(referrer_id: referrer_ids)
    end

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

    @referral_records = @referrals.order(created_at: :desc)
      .page(params[:page]).per(PER_PAGE)
      .includes(referrer: :grade, referred: :grade)
    @current_page = @referral_records.current_page
    @total_pages = @referral_records.total_pages
  end
end
