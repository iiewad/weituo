class Admin::CoursesController < AdminController
  def start
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:id])

    if @course.start!
      redirect_to admin_semester_klass_path(@sk), notice: "第 #{@course.seq} 课考勤已开始"
    elsif @course.started?
      redirect_to admin_semester_klass_path(@sk), alert: "第 #{@course.seq} 课已开课，无需重复操作"
    else
      blocked = @sk.courses.where("seq < ?", @course.seq).where(start_date: nil).order(:seq).first
      redirect_to admin_semester_klass_path(@sk),
        alert: "请先开第 #{blocked.seq} 课，开课需按课次顺序进行"
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_semester_klass_path(@sk), alert: "该课次正在开课，请刷新后重试"
  end

  # 批量开课：把截至所选课次的未开课课次按顺序依次开课；
  # 首节日期可自定义，之后各节按间隔天数累加（默认今天 / 7 天）
  def start_through
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    through_seq = params[:through_seq].to_i
    courses = @sk.courses.where(seq: ..through_seq).where(start_date: nil).order(:seq).to_a

    if through_seq <= 0 || courses.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "所选课次已开课或不存在"
      return
    end

    first_date = parse_start_date
    interval = parse_interval_days
    ActiveRecord::Base.transaction { courses.each_with_index { |course, i| course.start!(first_date + i * interval) } }
    last_date = first_date + (courses.size - 1) * interval
    first_seq = courses.first.seq
    notice = if first_seq == courses.last.seq
      "第 #{first_seq} 课考勤已开始（#{first_date.strftime("%m-%d")}）"
    else
      "已开第 #{first_seq}–#{courses.last.seq} 课（#{first_date.strftime("%m-%d")} ~ #{last_date.strftime("%m-%d")}）"
    end
    redirect_to admin_semester_klass_path(@sk), notice: notice
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_semester_klass_path(@sk), alert: "开课发生冲突，请刷新后重试"
  end

  private

  def parse_start_date
    Date.parse(params[:start_date].to_s)
  rescue Date::Error
    Date.today
  end

  def parse_interval_days
    return 7 if params[:interval_days].blank?
    params[:interval_days].to_i.clamp(0, 365)
  end
end
