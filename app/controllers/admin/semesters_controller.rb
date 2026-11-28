class Admin::SemestersController < AdminController
  before_action :require_admin, except: :switch_thread_semester

  def index
    @semesters = Current.campuse.semesters.order(:seq)
    @klass_counts = SemesterKlass.where(semester_id: @semesters.select(:id)).group(:semester_id).count
  end

  def create
    semester = Current.campuse.semesters.new(semester_params)

    if semester.save
      redirect_to admin_semesters_path, notice: "学期已添加"
    else
      redirect_to admin_semesters_path, alert: "学期添加失败，#{semester.errors.full_messages.join("；")}"
    end
  end

  def update
    semester = Current.campuse.semesters.find(params[:id])

    if semester.update(semester_params)
      redirect_to admin_semesters_path, notice: "学期已更新"
    else
      redirect_to admin_semesters_path, alert: "学期更新失败，#{semester.errors.full_messages.join("；")}"
    end
  end

  # 学期删除会级联删除其下班级、课次、考勤与预留记录，不可恢复；确认提示在视图里
  def destroy
    semester = Current.campuse.semesters.find(params[:id])

    semester.destroy
    redirect_to admin_semesters_path, notice: "学期「#{semester.name}」已删除"
  end

  def switch_thread_semester
    @semester = Current.campuse.semesters.find(params[:id])
    session[:current_semester_id] = @semester.id
    Current.semester = @semester
    redirect_after_context_switch("学期切换成功")
  end

  private
    def semester_params
      params.require(:semester).permit(:name, :seq, :current)
    end
end
